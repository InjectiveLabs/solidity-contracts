#!/usr/bin/env bash
#
# Swap precompile (0x68) demo on a fresh local chain.
#
# chain init -> EVM-native USDC (MintBurnBankERC20, erc20: denom) -> INJ/USDC
# spot market -> swap allowlist -> orderbook liquidity -> SwapDemo contract ->
# every precompile method, including partial fills and their detection.
#
# Requirements: injectived v1.21.0+ (or master), forge + cast, jq, python3.
# Run from anywhere: ./demos/swap/demo.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

INJECTIVED="${INJECTIVED:-injectived}"
HOME_DIR="${SWAP_DEMO_HOME:-$REPO_ROOT/.injectived-swap-demo}"
KEEP_NODE="${KEEP_NODE:-0}"

CHAIN_ID="injective-1"
KR=(--keyring-backend test --home "$HOME_DIR")
TXF=(--chain-id "$CHAIN_ID" --gas-prices 160000000inj --yes --broadcast-mode sync --output json)
RPC_PORT=26657
EVM_PORT=8545
GRPC_PORT=9900
API_PORT=10337
NODE="tcp://127.0.0.1:$RPC_PORT"
ETH_URL="http://127.0.0.1:$EVM_PORT"
SWAP="0x0000000000000000000000000000000000000068"
EVM_TX=(--rpc-url "$ETH_URL" --legacy --gas-price 160000000 --gas-limit 2000000)

INJ="0x0000000000000000000000000000000000000000" # address(0) is native INJ
INJ_TICK=1000000000000000                       # 0.001 INJ, the market's quantity tick

log() { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
fail() { printf '\033[31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }
# Formats a chain-format amount with the given decimals.
fmt() { python3 -c "from decimal import Decimal as D; print(f'{D(int(\"$1\"))/D(10**$2):f}')"; }

for bin in "$INJECTIVED" forge cast jq python3 curl; do
    command -v "$bin" > /dev/null || fail "$bin not found"
done

################################################################################
# helpers
################################################################################

# Broadcasts a cosmos tx, waits for inclusion and fails on a non-zero code.
cosmos_tx() {
    local desc="$1"; shift
    local out hash code
    out=$("$@" 2>&1) || fail "$desc: broadcast failed: $out"
    code=$(echo "$out" | jq -r '.code')
    [ "$code" = "0" ] || fail "$desc: CheckTx code $code: $(echo "$out" | jq -r '.raw_log')"
    hash=$(echo "$out" | jq -r '.txhash')
    for _ in $(seq 1 20); do
        if out=$("$INJECTIVED" q tx "$hash" --node "$NODE" --chain-id "$CHAIN_ID" --output json 2>/dev/null); then
            code=$(echo "$out" | jq -r '.code')
            [ "$code" = "0" ] || fail "$desc: DeliverTx code $code: $(echo "$out" | jq -r '.raw_log')"
            echo "ok: $desc"
            return
        fi
        sleep 1
    done
    fail "$desc: tx $hash not included"
}

# Sends an EVM tx with cast and fails unless it succeeded. Prints the receipt.
# Sends asynchronously and polls for the receipt: the JSON-RPC can briefly
# answer null for a just-included tx, which cast and forge treat as fatal.
evm_send() {
    local hash receipt
    hash=$(cast send "${EVM_TX[@]}" --private-key "$DEV1_PK" --async "$@") || fail "cast send ${*:1:2} failed"
    for _ in $(seq 1 30); do
        receipt=$(cast rpc eth_getTransactionReceipt "$hash" --rpc-url "$ETH_URL" 2> /dev/null || echo null)
        [ "$receipt" != "null" ] && break
        sleep 1
    done
    [ "$receipt" != "null" ] || fail "tx $hash not included"
    [ "$(echo "$receipt" | jq -r '.status')" = "0x1" ] || fail "tx reverted: $(echo "$receipt" | jq -c .)"
    echo "$receipt"
}

# Deploys <path:Contract> with <value> and ABI-encoded <constructor args>.
deploy() {
    local file="${1%%:*}" name="${1##*:}" bytecode receipt
    bytecode=$(jq -r '.bytecode.object' "out/$(basename "$file")/$name.json")
    receipt=$(evm_send --value "$2" --create "$bytecode${3#0x}") || exit 1
    cast to-check-sum-address "$(echo "$receipt" | jq -r '.contractAddress')"
}

# Decodes the SwapDemo events in a receipt.
print_swap_events() {
    local receipt="$1" data topic
    local exact_in_topic exact_out_topic
    exact_in_topic=$(cast keccak "SwappedExactInput(string,address,uint256,uint256,uint256,uint256)")
    exact_out_topic=$(cast keccak "SwappedExactOutput(address,uint256,uint256,uint256,uint256)")
    while read -r topic data; do
        if [ "$topic" = "$exact_in_topic" ]; then
            cast abi-decode --input "f(string,address,uint256,uint256,uint256,uint256)" "$data" |
                awk '{print $1}' | tr -d '"' | paste -sd'|' - |
                awk -F'|' '{printf "  method=%s tokenIn=%s\n  amountIn=%s amountInSpent=%s amountOut=%s balanceDebited=%s\n", $1,$2,$3,$4,$5,$6}'
        elif [ "$topic" = "$exact_out_topic" ]; then
            cast abi-decode --input "f(address,uint256,uint256,uint256,uint256)" "$data" |
                awk '{print $1}' | paste -sd'|' - |
                awk -F'|' '{printf "  tokenOut=%s amountOut=%s maxAmountIn=%s\n  amountInSpent=%s amountOutDelivered=%s\n", $1,$2,$3,$4,$5}'
        fi
    done < <(echo "$1" | jq -r --arg c "$(echo "$DEMO" | tr 'A-F' 'a-f')" \
        '.logs[] | select((.address | ascii_downcase) == $c) | "\(.topics[0]) \(.data)"')
}

contract_balances() {
    local usdc inj
    usdc=$(cast call "$USDC" "balanceOf(address)(uint256)" "$DEMO" --rpc-url "$ETH_URL" | awk '{print $1}')
    inj=$(cast balance "$DEMO" --rpc-url "$ETH_URL")
    echo "  SwapDemo holds $(fmt "$usdc" 6) USDC, $(fmt "$inj" 18) INJ"
}

# Strips cast's "[1e18]" annotations from a uint256 output line.
num() { awk '{print $1}'; }

deadline() { echo $(( $(date +%s) + 300 )); }

cleanup() {
    if [ -n "${NODE_PID:-}" ] && [ "$KEEP_NODE" != "1" ]; then
        kill "$NODE_PID" 2> /dev/null || true
    fi
}
trap cleanup EXIT

log "0) Compile the contracts"
forge build src/MintBurnBankERC20.sol examples/SwapDemo.sol > /dev/null || fail "forge build failed"
echo "ok"

################################################################################
log "1) Fresh chain in $HOME_DIR"
################################################################################

for port in $RPC_PORT $EVM_PORT $GRPC_PORT $API_PORT; do
    if lsof -nP -iTCP:"$port" -sTCP:LISTEN > /dev/null 2>&1; then
        fail "port $port is in use; stop the process using it first"
    fi
done

rm -rf "$HOME_DIR"
"$INJECTIVED" init swap-demo --chain-id "$CHAIN_ID" --home "$HOME_DIR" > /dev/null 2>&1
for key in val dev1 dev2; do
    "$INJECTIVED" keys add "$key" "${KR[@]}" > /dev/null 2>&1
done
DEV1=$("$INJECTIVED" keys show dev1 -a "${KR[@]}")
DEV2=$("$INJECTIVED" keys show dev2 -a "${KR[@]}")
echo "dev1 (exchange admin, contract owner): $DEV1"
echo "dev2 (market maker):                   $DEV2"

# dev1 becomes an exchange admin so it can allowlist the market without a
# governance vote. The gap between genesis and the first block looks like
# downtime and would put the exchange in post-only mode (no swaps) for
# post_only_mode_blocks_amount_after_downtime blocks; shorten that to one.
genesis="$HOME_DIR/config/genesis.json"
jq --arg admin "$DEV1" '
    .app_state.staking.params.bond_denom = "inj"
    | .app_state.mint.params.mint_denom = "inj"
    | .app_state.gov.params.min_deposit[0].denom = "inj"
    | .app_state.gov.params.expedited_min_deposit[0].denom = "inj"
    | .app_state.exchange.params.exchange_admins = [$admin]
    | .app_state.exchange.params.post_only_mode_blocks_amount_after_downtime = "1"
    | .app_state.evm.params.chain_config.cancun_time = "0"
    | .app_state.evm.params.chain_config.prague_time = "0"
    | .app_state.txfees.params.mempool1559_enabled = false
    | .consensus.params.block.max_gas = "150000000"
' "$genesis" > "$genesis.tmp" && mv "$genesis.tmp" "$genesis"
perl -i -pe 's/^timeout_commit = ".*?"/timeout_commit = "1000ms"/' "$HOME_DIR/config/config.toml"
perl -i -pe 's/^minimum-gas-prices = ".*?"/minimum-gas-prices = "1inj"/' "$HOME_DIR/config/app.toml"

for key in val dev1 dev2; do
    "$INJECTIVED" genesis add-genesis-account "$("$INJECTIVED" keys show $key -a "${KR[@]}")" \
        1000000000000000000000000inj --chain-id "$CHAIN_ID" --home "$HOME_DIR" > /dev/null
done
"$INJECTIVED" genesis gentx val 1000000000000000000000inj --chain-id "$CHAIN_ID" "${KR[@]}" > /dev/null 2>&1
"$INJECTIVED" genesis collect-gentxs --home "$HOME_DIR" > /dev/null 2>&1

################################################################################
log "2) Start the node"
################################################################################

"$INJECTIVED" start --home "$HOME_DIR" \
    --rpc.laddr "tcp://127.0.0.1:$RPC_PORT" \
    --grpc.address "127.0.0.1:$GRPC_PORT" \
    --api.enable=true --api.address "tcp://127.0.0.1:$API_PORT" \
    --json-rpc.enable=true \
    --json-rpc.address "127.0.0.1:$EVM_PORT" \
    --json-rpc.api "eth,net,web3,debug" \
    --log-level warn > "$HOME_DIR/node.log" 2>&1 &
NODE_PID=$!

for _ in $(seq 1 60); do
    if cast block-number --rpc-url "$ETH_URL" > /dev/null 2>&1; then
        height=$(cast block-number --rpc-url "$ETH_URL")
        [ "$height" -ge 2 ] && break
    fi
    kill -0 "$NODE_PID" 2> /dev/null || fail "node exited, see $HOME_DIR/node.log"
    sleep 1
done
echo "node pid $NODE_PID at height $(cast block-number --rpc-url "$ETH_URL"), log: $HOME_DIR/node.log"

export_key() { echo y | "$INJECTIVED" keys unsafe-export-eth-key "$1" "${KR[@]}" 2> /dev/null | tail -1; }
DEV1_PK="0x$(export_key dev1)"
DEV2_PK="0x$(export_key dev2)"
DEV1_EVM=$(cast wallet address --private-key "$DEV1_PK")
DEV2_EVM=$(cast wallet address --private-key "$DEV2_PK")
echo "dev1 EVM address: $DEV1_EVM"

################################################################################
log "3) Deploy an EVM-native USDC (MintBurnBankERC20, 6 decimals)"
################################################################################

# The constructor's value pays the 1 INJ bank denom creation fee.
USDC=$(deploy src/MintBurnBankERC20.sol:MintBurnBankERC20 1ether \
    "$(cast abi-encode "constructor(address,string,string,uint8)" "$DEV1_EVM" "Demo USDC" "USDC" 6)")
USDC_DENOM="erc20:$USDC"
echo "USDC: $USDC (bank denom $USDC_DENOM, no token pair)"

evm_send "$USDC" "mint(address,uint256)" "$DEV1_EVM" 1000000000000 > /dev/null
evm_send "$USDC" "mint(address,uint256)" "$DEV2_EVM" 1000000000000 > /dev/null
echo "minted 1,000,000 USDC each to dev1 and dev2"

################################################################################
log "4) Launch INJ/USDC and allowlist it for swaps"
################################################################################

cosmos_tx "instant-spot-market-launch INJ/USDC" \
    "$INJECTIVED" tx exchange instant-spot-market-launch INJ/USDC inj "$USDC_DENOM" \
    --min-price-tick-size=0.001 --min-quantity-tick-size=0.001 --min-notional=1 \
    --base-decimals=18 --quote-decimals=6 \
    --from dev1 --gas 3000000 --node "$NODE" "${KR[@]}" "${TXF[@]}"
MARKET_ID=$("$INJECTIVED" q exchange spot-markets --node "$NODE" --chain-id "$CHAIN_ID" --output json |
    jq -r '.markets[] | (.market // .) | select(.ticker == "INJ/USDC") | .market_id')
echo "market id: $MARKET_ID"

# MsgUpdateSwapParams has no CLI command; dev1 signs it as the exchange admin.
# It replaces the whole swap parameter group.
cat > "$HOME_DIR/swap-params.json" << EOF
{
  "body": {
    "messages": [{
      "@type": "/injective.exchange.v2.MsgUpdateSwapParams",
      "sender": "$DEV1",
      "swap_params": { "enabled": true, "allowed_markets": ["$MARKET_ID"] }
    }]
  },
  "auth_info": { "fee": { "amount": [{ "denom": "inj", "amount": "64000000000000000" }], "gas_limit": "400000" } },
  "signatures": []
}
EOF
"$INJECTIVED" tx sign "$HOME_DIR/swap-params.json" --from dev1 --chain-id "$CHAIN_ID" \
    --node "$NODE" "${KR[@]}" --output-document "$HOME_DIR/swap-params.signed.json" 2> /dev/null
cosmos_tx "MsgUpdateSwapParams" \
    "$INJECTIVED" tx broadcast "$HOME_DIR/swap-params.signed.json" --node "$NODE" --chain-id "$CHAIN_ID" \
    --broadcast-mode sync --output json "${KR[@]}"
echo "swap_params: $(curl -s "http://127.0.0.1:$API_PORT/injective/exchange/v2/exchangeParams" | jq -c '.params.swap_params')"

################################################################################
log "5) dev2 makes a market: asks 10 INJ @ 10.0 and 10.5, bids 10 INJ @ 9.5 and 9.0"
################################################################################

order() {
    cosmos_tx "$1 $2 INJ @ $3" \
        "$INJECTIVED" tx exchange create-spot-limit-order "$1" INJ/USDC "$2" "$3" "$4" \
        --from dev2 --gas 600000 --node "$NODE" "${KR[@]}" "${TXF[@]}"
}
order sell 10 10.0 ask-1
order sell 10 10.5 ask-2
order buy 10 9.5 bid-1
order buy 10 9.0 bid-2

################################################################################
log "6) Deploy SwapDemo and fund it with 1,000 USDC and 50 INJ"
################################################################################

DEMO=$(deploy examples/SwapDemo.sol:SwapDemo 0 0x)
echo "SwapDemo: $DEMO"
evm_send "$USDC" "transfer(address,uint256)" "$DEMO" 1000000000 > /dev/null
evm_send "$DEMO" --value 50ether > /dev/null
contract_balances

################################################################################
log "7) Quotes: buy INJ with 50 USDC"
################################################################################

q1=$(cast call "$SWAP" "quoteExactInputV1(address,string,uint256)(uint256)" \
    "$USDC" "$MARKET_ID" 50000000 --rpc-url "$ETH_URL" | num)
echo "quoteExactInputV1: amountOut=$q1 ($(fmt "$q1" 18) INJ)"
q2=$(cast call "$SWAP" "quoteExactInputV2(address,string,uint256)(uint256,uint256)" \
    "$USDC" "$MARKET_ID" 50000000 --rpc-url "$ETH_URL" | num | paste -sd' ' -)
read -r q2_spent q2_out <<< "$q2"
echo "quoteExactInputV2: amountInSpent=$q2_spent ($(fmt "$q2_spent" 6) USDC) amountOut=$q2_out ($(fmt "$q2_out" 18) INJ)"

################################################################################
log "8) swapExactInputV2: buy INJ with 50 USDC, minOut from a limit price of 10.2"
################################################################################

# A limit price bounds the worst fill independently of the book. A minOut
# derived from a quote would just track whatever the book offers right now.
min_out=$(python3 -c "print(50 * 10**18 * 10 // 102)")
echo "minOut = 50 USDC / 10.2 = $(fmt "$min_out" 18) INJ"
receipt=$(evm_send "$DEMO" \
    "swapExactInputV2(address,string,uint256,uint256,uint256,address,uint256)" \
    "$USDC" "$MARKET_ID" 50000000 "$min_out" 1000000 "$INJ" "$(deadline)")
print_swap_events "$receipt"
echo "  -> balanceDebited can be 1 unit below amountInSpent: the sub-unit"
echo "     remainder of the fee-inclusive cost stays as dust in the subaccount."
contract_balances

################################################################################
log "9) swapExactInputV2: sell 1.0005 INJ (address(0)) for USDC, limit price 9.0"
################################################################################

min_out=9000000
echo "amountIn is not a whole number of 0.001 INJ ticks; minOut = 1.000 INJ * 9.0 = 9 USDC"
echo "maxUnspent = one tick (0.001 INJ): anything more would be a partial fill"
receipt=$(evm_send "$DEMO" \
    "swapExactInputV2(address,string,uint256,uint256,uint256,address,uint256)" \
    "$INJ" "$MARKET_ID" 1000500000000000000 "$min_out" "$INJ_TICK" "$INJ" "$(deadline)")
print_swap_events "$receipt"
echo "  -> a full fill, yet amountInSpent < amountIn: fills are floored to the"
echo "     quantity tick, so 'spent == amountIn' is not a full-fill check."
contract_balances

################################################################################
log "10) swapExactInputV1: sell 0.5 INJ for USDC (legacy, output only)"
################################################################################

receipt=$(evm_send "$DEMO" \
    "swapExactInputV1(address,string,uint256,uint256,address,uint256)" \
    "$INJ" "$MARKET_ID" 500000000000000000 4500000 "$INJ" "$(deadline)")
print_swap_events "$receipt"
echo "  -> V1 reports amountOut only; the contract measured balanceDebited itself."

################################################################################
log "11) swapExactOutputV1: buy exactly 2 INJ, delivered to a fresh address"
################################################################################

need=$(cast call "$SWAP" "quoteExactOutputV1(address,string,uint256)(uint256)" \
    "$INJ" "$MARKET_ID" 2000000000000000000 --rpc-url "$ETH_URL" | num)
max_in=$(( need * 101 / 100 ))
echo "quoteExactOutputV1: amountIn=$need ($(fmt "$need" 6) USDC); maxAmountIn=+1% = $(fmt "$max_in" 6) USDC"
recipient=$(cast wallet new --json | jq -r '.[0].address')
receipt=$(evm_send "$DEMO" \
    "swapExactOutputV1(address,string,uint256,uint256,address,uint256)" \
    "$INJ" "$MARKET_ID" 2000000000000000000 "$max_in" "$recipient" "$(deadline)")
print_swap_events "$receipt"
echo "  recipient $recipient now holds $(fmt "$(cast balance "$recipient" --rpc-url "$ETH_URL")" 18) INJ"

echo ""
echo "maxAmountIn below the quote reverts instead of filling partially:"
if out=$(cast call "$DEMO" --from "$DEV1_EVM" \
    "swapExactOutputV1(address,string,uint256,uint256,address,uint256)" \
    "$INJ" "$MARKET_ID" 2000000000000000000 $(( need - 1 )) "$INJ" "$(deadline)" \
    --rpc-url "$ETH_URL" 2>&1); then
    fail "expected a revert, got $out"
fi
echo "  $(echo "$out" | grep -oE 'required input [0-9]+ is above maximum [0-9]+' | head -1)"

################################################################################
log "12) Over-depth: try to buy INJ with 500 USDC"
################################################################################

echo "remaining asks: 20 placed - 4.992 - 2 bought = 13.008 INJ, worth ~135 USDC"

q1=$(cast call "$SWAP" "quoteExactInputV1(address,string,uint256)(uint256)" \
    "$USDC" "$MARKET_ID" 500000000 --rpc-url "$ETH_URL" | num)
echo "quoteExactInputV1: amountOut=$(fmt "$q1" 18) INJ   (nothing says this is partial)"
q2=$(cast call "$SWAP" "quoteExactInputV2(address,string,uint256)(uint256,uint256)" \
    "$USDC" "$MARKET_ID" 500000000 --rpc-url "$ETH_URL" | num | paste -sd' ' -)
read -r q2_spent q2_out <<< "$q2"
echo "quoteExactInputV2: amountInSpent=$(fmt "$q2_spent" 6) USDC of 500, amountOut=$(fmt "$q2_out" 18) INJ"

echo ""
echo "Strict swap (maxUnspent = 1 USDC) reverts and rolls the swap back:"
if out=$(cast call "$DEMO" --from "$DEV1_EVM" \
    "swapExactInputV2(address,string,uint256,uint256,uint256,address,uint256)" \
    "$USDC" "$MARKET_ID" 500000000 0 1000000 "$INJ" "$(deadline)" \
    --rpc-url "$ETH_URL" 2>&1); then
    fail "expected PartialFill, got $out"
fi
revert_data=$(echo "$out" | grep -oE '0x[0-9a-fA-F]{8,}' | tail -1)
echo "  PartialFill(amountIn, amountInSpent, maxUnspent) = $(cast decode-error --sig "PartialFill(uint256,uint256,uint256)" "$revert_data" | awk '{print $1}' | paste -sd' ' -)"

echo ""
echo "Lenient swap (maxUnspent = max) takes what the book has; the rest stays:"
receipt=$(evm_send "$DEMO" \
    "swapExactInputV2(address,string,uint256,uint256,uint256,address,uint256)" \
    "$USDC" "$MARKET_ID" 500000000 0 \
    115792089237316195423570985008687907853269984665640564039457584007913129639935 \
    "$INJ" "$(deadline)")
print_swap_events "$receipt"
contract_balances

################################################################################
log "13) Withdraw everything back to dev1"
################################################################################

usdc_left=$(cast call "$USDC" "balanceOf(address)(uint256)" "$DEMO" --rpc-url "$ETH_URL" | num)
inj_left=$(cast balance "$DEMO" --rpc-url "$ETH_URL")
evm_send "$DEMO" "withdraw(address,address,uint256)" "$USDC" "$DEV1_EVM" "$usdc_left" > /dev/null
evm_send "$DEMO" "withdraw(address,address,uint256)" "$INJ" "$DEV1_EVM" "$inj_left" > /dev/null
contract_balances

log "Done"
if [ "$KEEP_NODE" = "1" ]; then
    echo "Node left running (pid $NODE_PID). Market $MARKET_ID, USDC $USDC, SwapDemo $DEMO."
    trap - EXIT
fi
