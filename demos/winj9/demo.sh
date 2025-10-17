#!/bin/sh

# Load environment variables
if [ -f ./.local.env ]; then
    source ./.local.env
else
    echo "Error: .local.env file not found"
    exit 1
fi

: ${INJ_HOME:=~/.injectived}
echo "User injectived home: $INJ_HOME"

################################################################################

check_foundry_result() {
    res=$1
    
    eth_tx_hash=$(echo $res | jq -r '.transactionHash')
    sdk_tx_hash=$(cast rpc inj_getTxHashByEthHash $eth_tx_hash -r $ETH_URL | sed -r 's/0x//' | tr -d '"')

    tx_receipt=$(injectived q tx $sdk_tx_hash --node $INJ_URL --output json)
    code=$(echo $tx_receipt | jq -r '.code')
    raw_log=$(echo $tx_receipt | jq -r '.raw_log')

    if [ $code -ne 0 ]; then
        echo "Error: Tx Failed. Code: $code, Log: $raw_log"

        # Get detailed transaction trace for debugging
        echo "Getting transaction trace..."
        cast rpc debug_traceTransaction "[\"$eth_tx_hash\",{\"tracer\":\"callTracer\"}]" --raw -r $ETH_URL | jq
        exit 1
    fi
}

echo "1) Importing user wallet..."
if cast wallet list | grep -q $USER; then
    echo "Wallet $USER already exists. Skipping import."
else
    cast wallet import $USER \
        --unsafe-password "$USER_PWD" \
        --mnemonic "$USER_MNEMONIC"
fi
user_inj_address=$(yes $USER_PWD | injectived --home $INJ_HOME keys show -a $USER)
user_eth_address=$(injectived q exchange eth-address-from-inj-address $user_inj_address)
echo "User INJ address: $user_inj_address"
echo "User ETH address: $user_eth_address"
echo ""

echo "2) Creating contract..."
create_res=$(forge create src/WINJ9.sol:WINJ9 \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --broadcast \
    --legacy \
    --gas-limit 10000000 \
    --gas-price 10 \
    --value 1000000000000000000 \
    -vvvv \
    --json \
    --constructor-args "Wrapped INJ" "WINJ" 18) 
if [ $? -ne 0 ]; then
    exit 1
fi
check_foundry_result "$create_res"

contract_eth_address=$(echo $create_res | jq -r '.deployedTo')
contract_inj_address=$(injectived q exchange inj-address-from-eth-address $contract_eth_address)
denom="erc20:$contract_eth_address"
echo "Contract ETH address: $contract_eth_address"
echo "Contract INJ address: $contract_inj_address"
echo "Denom: $denom"
echo ""

echo "3) Depositing 100 INJ..."
mint_res=$(cast send \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --json \
    --legacy \
    --gas-limit 1000000 \
    --gas-price 10 \
    --value 100000000000000000000 \
    $contract_eth_address \
    "deposit()")
if [ $? -ne 0 ]; then
    exit 1
fi
check_foundry_result "$mint_res"
echo "OK"
echo ""

# Query balances through cosmos x/bank
echo "4) Querying balances through cosmos x/bank..."
sleep 3
injectived q bank balances \
    --chain-id $CHAIN_ID \
    --node $INJ_URL \
    --output json \
    $user_inj_address \
    | jq -r '.balances[] | select(.denom == "'$denom'" or .denom == "inj") | "\(.denom): \(.amount)"'
echo ""

# Transfer
echo "6) Transfer 5 WINJ..."
transfer_res=$(cast send \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --json \
    --legacy \
    --gas-limit 1000000 \
    --gas-price 10 \
    $contract_eth_address \
    "transfer(address,uint256)" 0x0b3D624F163F7135E1C5A7a777133e4126B96246 5000000000000000000)
if [ $? -ne 0 ]; then
    exit 1
fi
check_foundry_result "$transfer_res"
echo "OK"
echo ""


# Query balances through cosmos x/bank
echo "7) Querying balances through cosmos x/bank..."
sleep 3
injectived q bank balances \
    --chain-id $CHAIN_ID \
    --node $INJ_URL \
    --output json \
    $user_inj_address \
    | jq -r '.balances[] | select(.denom == "'$denom'" or .denom == "inj") | "\(.denom): \(.amount)"'
echo ""

echo "8) Withdraw 50 WINJ..."
mint_res=$(cast send \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --json \
    --legacy \
    --gas-limit 1000000 \
    --gas-price 10 \
    $contract_eth_address \
    "withdraw(uint256)" 50000000000000000000)
if [ $? -ne 0 ]; then
    exit 1
fi
check_foundry_result "$mint_res"
echo "OK"
echo ""

# Query balances through cosmos x/bank
echo "9) Querying balances through cosmos x/bank..."
sleep 3
injectived q bank balances \
    --chain-id $CHAIN_ID \
    --node $INJ_URL \
    --output json \
    $user_inj_address \
    | jq -r '.balances[] | select(.denom == "'$denom'" or .denom == "inj") | "\(.denom): \(.amount)"'
echo ""