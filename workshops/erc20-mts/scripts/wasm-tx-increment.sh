#!/bin/sh

source .local.env

if [ -z "$WASM_CONTRACT" ]; then
  echo "⚠️  Error: WASM_CONTRACT env variable is not set"
  exit 1
fi

USER_INJ_ADDRESS=$(injectived keys show $USER --keyring-backend=test -a)\

# Check if $DENOM was provided
if [ -z "$1" ]; then
  echo "⚠️  Error: No value with ERC20 denom specified"
  echo "Usage: $0 <value>erc20:<contract_address>"
  exit 1
fi

echo "Incrementing counter contract..."

echo "\n### EXECUTING INCREMENT ###"
echo injectived tx wasm execute $WASM_CONTRACT '{"increment":{}}' \
    --amount $1 \
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

execute_res=$(injectived tx wasm execute $WASM_CONTRACT '{"increment":{}}' \
    --amount $1 \
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
    echo "Failed to execute increment on WASM contract"
    exit 1
fi

# Extract txhash from execute transaction response
TXHASH=$(echo $execute_res | jq -r '.txhash')
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

# Check if transaction was successful
TX_CODE=$(echo $tx_result | jq -r '.code')
if [ "$TX_CODE" = "0" ]; then
    echo "✅ Transaction successful!"
else
    echo "❌ Transaction failed with code: $TX_CODE"
    echo "Error: $(echo $tx_result | jq -r '.raw_log')"
    exit 1
fi
