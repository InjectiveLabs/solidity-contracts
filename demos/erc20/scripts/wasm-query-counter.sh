#!/bin/sh

source .local.env

if [ -z "$WASM_CONTRACT" ]; then
  echo "⚠️  Error: WASM_CONTRACT env variable is not set"
  exit 1
fi

USER_INJ_ADDRESS=$(injectived keys show $USER --keyring-backend=test -a)

echo "Querying counter contract..."

echo "\n### QUERYING COUNT ###"
echo injectived q wasm contract-state smart $WASM_CONTRACT \
    '{"get_count":{"addr":"'$USER_INJ_ADDRESS'"}}' \
    --node $INJ_URL \
    --output json
echo "######################\n"

count_response=$(injectived q wasm contract-state smart $WASM_CONTRACT \
    '{"get_count":{"addr":"'$USER_INJ_ADDRESS'"}}' \
    --node $INJ_URL \
    --output json)
if [ $? -ne 0 ]; then
    echo "Failed to query count from contract"
    exit 1
fi

count=$(echo $count_response | jq -r '.data.count')
echo "Count: $count"
echo ""

echo "\n### QUERYING TOTAL FUNDS ###"
echo injectived q wasm contract-state smart $WASM_CONTRACT \
    '{"get_total_funds":{"addr":"'$USER_INJ_ADDRESS'"}}' \
    --node $INJ_URL \
    --output json
echo "######################\n"

funds_response=$(injectived q wasm contract-state smart $WASM_CONTRACT \
    '{"get_total_funds":{"addr":"'$USER_INJ_ADDRESS'"}}' \
    --node $INJ_URL \
    --output json)
if [ $? -ne 0 ]; then
    echo "Failed to query total funds from contract"
    exit 1
fi

echo "Total Funds:"
echo $funds_response | jq -r '.data.total_funds'
echo ""
