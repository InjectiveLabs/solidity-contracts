#!/usr/bin/env bash
#
# Starts a single-node Injective localnet in Docker for the demos in this repo.
#
# It uses the public injectivelabs/injective-core image and sets up what the
# demos expect: chain ID injective-1, a file keyring with passphrase 12345678
# holding user1 (the mnemonic in demos/*/.local.env) and user2, both funded
# with INJ and USDT (peggy0xdAC17F958D2ee523a2206206994597C13D831ec7), and an
# INJ/USDT PERP market priced by a "local" provider oracle.
#
# Run demos/localnet/stop.sh to stop it. Requirements: docker, jq, curl.

set -eEuo pipefail
# Some steps hide their output; name the command that failed instead of
# exiting silently.
trap 'printf "\033[31mERROR: line %s failed: %s\033[0m\n" "$LINENO" "$BASH_COMMAND" >&2' ERR

LOCALNET_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$LOCALNET_DIR/../.." && pwd)"

IMAGE="${INJECTIVED_IMAGE:-injectivelabs/injective-core:v1.21.0}"
DEFAULT_INJHOME="$REPO_ROOT/.injectived"
INJHOME="${INJHOME:-$DEFAULT_INJHOME}"
CONTAINER="${LOCALNET_CONTAINER:-injective-localnet}"

CHAIN_ID="injective-1"
PASSPHRASE="12345678"
USDT="peggy0xdAC17F958D2ee523a2206206994597C13D831ec7"
# Same test-only mnemonic as demos/*/.local.env. Never use it with real funds.
USER1_MNEMONIC="copper push brief egg scan entry inform record adjust fossil boss egg comic alien upon aspect dry avoid interest fury window hint race symptom"
INJ_PRICE="1.461"
PORTS=(26657 8545 8546 9900 10337)

# Feeds the keyring passphrase to every prompt. `yes` dies of SIGPIPE when the
# reader exits, which pipefail would otherwise report as a failure.
pw() { yes "$PASSPHRASE" 2> /dev/null || true; }

log() { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }
fail() { printf '\033[31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

for bin in docker jq curl; do
    command -v "$bin" > /dev/null || fail "$bin not found"
done

# The chain home must be an absolute path: Docker mounts need one, and the
# demos run from their own directories. A relative INJHOME is taken relative to
# the current directory. Symlinks are kept as given (no `pwd -P`), so the
# mount path is the same string the demos pass to --home.
case "$INJHOME" in
    /*) ;;
    *) INJHOME="$PWD/$INJHOME" ;;
esac
INJHOME="${INJHOME%/}"
case "$(basename "$INJHOME")" in
    "" | . | ..) fail "INJHOME must name a directory, got: $INJHOME" ;;
esac
mkdir -p "$(dirname "$INJHOME")"
INJHOME="$(cd "$(dirname "$INJHOME")" && pwd)/$(basename "$INJHOME")"

# Files are created as the current user, and the repo (plus INJHOME, if it is
# elsewhere) is mounted at the same path, so host paths work in the container.
DOCKER_USER=(--user "$(id -u):$(id -g)" -e HOME=/tmp)
MOUNTS=(-v "$REPO_ROOT:$REPO_ROOT")
case "$INJHOME/" in
    "$REPO_ROOT"/*) ;;
    *) MOUNTS+=(-v "$INJHOME:$INJHOME") ;;
esac

# injectived in a one-off container, before the node runs.
inj() {
    docker run --rm -i "${DOCKER_USER[@]}" "${MOUNTS[@]}" --entrypoint injectived "$IMAGE" "$@"
}

# injectived in the node's container, which reaches the node on localhost.
injx() {
    docker exec -i "${DOCKER_USER[@]}" "$CONTAINER" injectived "$@"
}

TXF=(--from user1 --home "$INJHOME" --keyring-backend file --chain-id "$CHAIN_ID"
    --gas 2000000 --gas-prices 500000000inj --broadcast-mode sync --yes --output json)

# Broadcasts a tx signed by user1, waits for inclusion and fails on a non-zero code.
tx() {
    local desc="$1"; shift
    local out hash code
    out=$(pw | injx tx "$@" "${TXF[@]}" 2>&1) || fail "$desc: $out"
    out=$(echo "$out" | grep '^{' | tail -1)
    code=$(echo "$out" | jq -r '.code')
    [ "$code" = "0" ] || fail "$desc: CheckTx code $code: $(echo "$out" | jq -r '.raw_log')"
    hash=$(echo "$out" | jq -r '.txhash')
    for _ in $(seq 1 20); do
        if out=$(injx q tx "$hash" --output json 2> /dev/null); then
            code=$(echo "$out" | jq -r '.code')
            [ "$code" = "0" ] || fail "$desc: DeliverTx code $code: $(echo "$out" | jq -r '.raw_log')"
            echo "ok: $desc"
            return
        fi
        sleep 1
    done
    fail "$desc: tx $hash not included"
}

################################################################################
log "1) Checks"
################################################################################

if docker inspect "$CONTAINER" > /dev/null 2>&1; then
    fail "container $CONTAINER already exists; run demos/localnet/stop.sh first"
fi
for port in "${PORTS[@]}"; do
    if lsof -nP -iTCP:"$port" -sTCP:LISTEN > /dev/null 2>&1; then
        fail "port $port is in use; stop the process using it first"
    fi
done
if [ -e "$INJHOME" ] && [ ! -f "$INJHOME/.localnet" ]; then
    # Only wipe a home this script created.
    fail "$INJHOME exists and was not created by this script; remove it or set INJHOME"
fi
docker image inspect "$IMAGE" > /dev/null 2>&1 || docker pull "$IMAGE"
echo "image: $IMAGE"
echo "home:  $INJHOME"

################################################################################
log "2) Genesis"
################################################################################

# Recreated from inside a container: deleting and recreating a bind-mounted
# directory from the host can leave Docker Desktop with a stale view of it.
mkdir -p "$INJHOME"
docker run --rm "${DOCKER_USER[@]}" "${MOUNTS[@]}" --entrypoint sh "$IMAGE" \
    -c 'find "$0" -mindepth 1 -delete && touch "$0/.localnet"' "$INJHOME"
out=$(inj init localnet --chain-id "$CHAIN_ID" --home "$INJHOME" 2>&1) || fail "init: $out"

pw | inj keys add val --home "$INJHOME" --keyring-backend file > /dev/null 2>&1
printf '%s\n%s\n%s\n' "$USER1_MNEMONIC" "$PASSPHRASE" "$PASSPHRASE" |
    inj keys add user1 --recover --home "$INJHOME" --keyring-backend file > /dev/null 2>&1
pw | inj keys add user2 --home "$INJHOME" --keyring-backend file > /dev/null 2>&1
addr() { pw | inj keys show "$1" -a --home "$INJHOME" --keyring-backend file; }
VAL=$(addr val)
USER1=$(addr user1)
USER2=$(addr user2)
echo "user1: $USER1"
echo "user2: $USER2"

# Derivatives and instant perp launches are disabled in a default genesis;
# enable them and make user1 the exchange admin that launches the perp
# market. The quote denom needs bank metadata. user1 also relays the "local" provider's INJ price. A fresh genesis looks like
# downtime, which would hold the exchange in post-only mode for a while;
# shorten that to one block.
genesis="$INJHOME/config/genesis.json"
jq --arg user1 "$USER1" --arg usdt "$USDT" --arg price "$INJ_PRICE" --arg now "$(date +%s)" '
    .app_state.staking.params.bond_denom = "inj"
    | .app_state.mint.params.mint_denom = "inj"
    | .app_state.gov.params.min_deposit[0].denom = "inj"
    | .app_state.gov.params.expedited_min_deposit[0].denom = "inj"
    | .app_state.gov.params.voting_period = "10s"
    | .app_state.gov.params.expedited_voting_period = "5s"
    | .app_state.exchange.params.post_only_mode_blocks_amount_after_downtime = "1"
    | .app_state.exchange.is_spot_exchange_enabled = true
    | .app_state.exchange.is_derivatives_exchange_enabled = true
    | .app_state.exchange.params.is_instant_derivative_market_launch_enabled = true
    | .app_state.exchange.params.exchange_admins = [$user1]
    | .app_state.oracle.provider_states = [{
        provider_info: { provider: "local", relayers: [$user1] },
        provider_price_states: [{
            symbol: "INJ",
            state: { price: $price, cumulative_price: "0", timestamp: $now }
        }]
    }]
    | .app_state.bank.denom_metadata += [{
        description: "Tether USD (localnet)", base: $usdt, display: "USDT",
        name: "Tether USD", symbol: "USDT", decimals: 6,
        denom_units: [{ denom: $usdt, exponent: 0 }, { denom: "USDT", exponent: 6 }]
    }]
    | .app_state.evm.params.chain_config.cancun_time = "0"
    | .app_state.evm.params.chain_config.prague_time = "0"
    | .app_state.txfees.params.mempool1559_enabled = false
    | .consensus.params.block.max_gas = "150000000"
' "$genesis" > "$genesis.tmp" && mv "$genesis.tmp" "$genesis"
perl -i -pe 's/^timeout_commit = ".*?"/timeout_commit = "1000ms"/' "$INJHOME/config/config.toml"
perl -i -pe 's/^minimum-gas-prices = ".*?"/minimum-gas-prices = "1inj"/' "$INJHOME/config/app.toml"

# 1,000,000 INJ and 100,000,000 USDT each.
for a in "$VAL" "$USER1" "$USER2"; do
    inj genesis add-genesis-account "$a" "1000000000000000000000000inj,100000000000000$USDT" \
        --chain-id "$CHAIN_ID" --home "$INJHOME" > /dev/null
done
pw | inj genesis gentx val 1000000000000000000000inj --chain-id "$CHAIN_ID" \
    --home "$INJHOME" --keyring-backend file > /dev/null 2>&1
inj genesis collect-gentxs --home "$INJHOME" > /dev/null 2>&1
echo "ok"

################################################################################
log "3) Start the node"
################################################################################

ports=()
for port in "${PORTS[@]}"; do
    ports+=(-p "127.0.0.1:$port:$port")
done
# The label records the chain home; bin/injectived checks --home against it.
docker run -d --name "$CONTAINER" --label "injective-localnet.home=$INJHOME" \
    "${DOCKER_USER[@]}" "${MOUNTS[@]}" "${ports[@]}" \
    --entrypoint sh "$IMAGE" -c 'exec injectived "$@" > "$0" 2>&1' "$INJHOME/node.log" \
    start --home "$INJHOME" \
    --rpc.laddr "tcp://0.0.0.0:26657" \
    --grpc.address "0.0.0.0:9900" \
    --api.enable=true --api.address "tcp://0.0.0.0:10337" \
    --json-rpc.enable=true \
    --json-rpc.address "0.0.0.0:8545" \
    --json-rpc.ws-address "0.0.0.0:8546" \
    --json-rpc.api "eth,web3,net,txpool,debug,personal,inj" \
    --json-rpc.allow-unprotected-txs=true \
    --log-level warn > /dev/null

height=0
for _ in $(seq 1 60); do
    height=$(curl -s http://127.0.0.1:26657/status | jq -r '.result.sync_info.latest_block_height' 2> /dev/null || echo 0)
    [ "${height:-0}" -ge 2 ] 2> /dev/null && break
    [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2> /dev/null)" = "true" ] ||
        fail "node exited, see $INJHOME/node.log"
    sleep 1
done
[ "${height:-0}" -ge 2 ] 2> /dev/null || fail "node did not produce blocks, see $INJHOME/node.log"
echo "container $CONTAINER at height $height"

################################################################################
log "4) INJ/USDT PERP market"
################################################################################

tx "create insurance fund" insurance create-insurance-fund \
    --ticker "INJ/USDT PERP" --quote-denom "$USDT" \
    --oracle-base INJ --oracle-quote local --oracle-type provider \
    --expiry -1 --initial-deposit "10000000000$USDT"
tx "launch INJ/USDT PERP" exchange instant-perpetual-market-launch \
    --ticker "INJ/USDT PERP" --quote-denom "$USDT" \
    --oracle-base INJ --oracle-quote local --oracle-type provider --oracle-scale-factor 0 \
    --maker-fee-rate -0.0001 --taker-fee-rate 0.001 \
    --initial-margin-ratio 0.05 --maintenance-margin-ratio 0.02 --reduce-margin-ratio 0.05 \
    --min-price-tick-size 0.001 --min-quantity-tick-size 0.001
MARKET_ID=$(injx q exchange derivative-markets --chain-id "$CHAIN_ID" --output json |
    jq -r '.markets[] | (.market // .) | select(.ticker == "INJ/USDT PERP") | .market_id')
[ -n "$MARKET_ID" ] || fail "INJ/USDT PERP market not found"
echo "market id: $MARKET_ID"

log "Localnet is running"
cat << EOF
EVM JSON-RPC  http://localhost:8545
Tendermint    http://localhost:26657
gRPC          localhost:9900
REST          http://localhost:10337
Home          $INJHOME (keyring passphrase $PASSPHRASE)
Node log      $INJHOME/node.log

Run the demos' injectived commands in the container:
  export PATH="$LOCALNET_DIR/bin:\$PATH"
Stop it with:
  $LOCALNET_DIR/stop.sh
EOF
if [ "$INJHOME" != "$DEFAULT_INJHOME" ]; then
    printf '\nThe demos read the chain home from INJHOME. In the shell you run them from:\n  export INJHOME="%s"\n' "$INJHOME"
fi
