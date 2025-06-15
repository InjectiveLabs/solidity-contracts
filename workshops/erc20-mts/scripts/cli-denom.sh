#!/bin/sh

echo "Getting denom..."

source .local.env

# Check if an argument was provided
if [ -z "$1" ]; then
  echo "⚠️  Error: No denom specified"
  echo "Usage: $0 <denom>"
  exit 1
fi

# Check if denom starts with erc20: prefix
if [[ "$1" != erc20:* ]]; then
  echo "⚠️  Error: Denom must start with 'erc20:' prefix"
  echo "Usage: $0 erc20:<contract_address>"
  exit 1
fi

echo "\n### QUERYING DENOM ###"
echo injectived q bank denom-metadata $1 \
    --node $INJ_URL
echo "######################\n"

injectived q bank denom-metadata $1 --node $INJ_URL
