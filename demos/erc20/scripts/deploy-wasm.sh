#!/bin/sh

source .local.env

echo "Deploying and instantiating WASM contract..."

# Get the user's address
USER_ADDRESS=$(injectived keys show $USER --keyring-backend=test -a)

echo "\n### RUNNING WASM STORE ###"
echo injectived tx wasm store wasm/counter.wasm \
    --from $USER \
    --chain-id $CHAIN_ID \
    --node $INJ_URL \
    --gas-prices 500000000inj \
    --gas auto \
    --gas-adjustment 1.3 \
    --broadcast-mode sync \
    --keyring-backend test \
    --output json \
    -y
echo "########################\n"

store_res=$(injectived tx wasm store wasm/counter.wasm \
    --from $USER \
    --chain-id $CHAIN_ID \
    --node $INJ_URL \
    --gas-prices 500000000inj \
    --gas auto \
    --gas-adjustment 1.3 \
    --broadcast-mode sync \
    --keyring-backend test \
    -y --output json)
if [ $? -ne 0 ]; then
    echo "Failed to store WASM contract"
    exit 1
fi

# Extract txhash from store transaction response
TXHASH=$(echo $store_res | jq -r '.txhash')
echo "Transaction hash: $TXHASH"

sleep 2

echo "\n### QUERYING TRANSACTION ###"
echo injectived q tx $TXHASH \
    --node $INJ_URL \
    --chain-id $CHAIN_ID \
    --output json
echo "########################\n"

# Query the transaction to get the actual results
tx_result=$(injectived q tx $TXHASH \
    --node $INJ_URL \
    --chain-id $CHAIN_ID \
    --output json)
if [ $? -ne 0 ]; then
    echo "Failed to query transaction"
    exit 1
fi

# Update store_res with the full transaction result
store_res=$tx_result

# Extract code ID from transaction response
CODE_ID=$(echo $store_res | jq -r '.events[] | select(.type=="store_code") | .attributes[] | select(.key=="code_id") | .value')
echo "Contract Code ID: $CODE_ID"

sleep 2

echo "\n### RUNNING WASM INSTANTIATE ###"
echo injectived tx wasm instantiate $CODE_ID '{"count":0}' \
    --label "counter-1.0.0" \
    --admin $USER_ADDRESS \
    --from $USER \
    --chain-id $CHAIN_ID \
    --node $INJ_URL \
    --gas-prices 500000000inj \
    --gas auto \
    --gas-adjustment 1.3 \
    --broadcast-mode sync \
    --keyring-backend test \
    --output json \
    -y
echo "############################\n"

instantiate_res=$(injectived tx wasm instantiate $CODE_ID '{"count":0}' \
    --label "counter-1.0.0" \
    --admin $USER_ADDRESS \
    --from $USER \
    --chain-id $CHAIN_ID \
    --node $INJ_URL \
    --gas-prices 500000000inj \
    --gas auto \
    --gas-adjustment 1.3 \
    --broadcast-mode sync \
    --keyring-backend test \
    -y --output json)
if [ $? -ne 0 ]; then
    echo "Failed to instantiate WASM contract"
    exit 1
fi

# Extract txhash from instantiate transaction response
TXHASH=$(echo $instantiate_res | jq -r '.txhash')
echo "Transaction hash: $TXHASH"

sleep 2

echo "\n### QUERYING TRANSACTION ###"
echo injectived q tx $TXHASH \
    --node $INJ_URL \
    --chain-id $CHAIN_ID \
    --output json
echo "########################\n"

# Query the transaction to get the actual results
tx_result=$(injectived q tx $TXHASH \
    --node $INJ_URL \
    --chain-id $CHAIN_ID \
    --output json)
if [ $? -ne 0 ]; then
    echo "Failed to query transaction"
    exit 1
fi

# Update instantiate_res with the full transaction result
instantiate_res=$tx_result

# Extract contract address from instantiation response
CONTRACT_ADDRESS=$(echo $instantiate_res | jq -r '.events[] | select(.type=="instantiate") | .attributes[] | select(.key=="_contract_address") | .value')
echo "Contract address: $CONTRACT_ADDRESS"
echo ""
