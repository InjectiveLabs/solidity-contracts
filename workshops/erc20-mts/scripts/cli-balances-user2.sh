#!/bin/sh

source .local.env

echo "Checking balance of user2..."

if [ -z "$USER_INJ_ADDRESS" ]; then
  echo "⚠️  Error: USER_INJ_ADDRESS env variable is not set"
  exit 1
fi

echo "\n### RUNNING ###"
echo injectived q bank balances $1 --chain-id $CHAIN_ID --node $INJ_URL --keyring-backend=test
echo "###############\n"

injectived q bank balances $1 --chain-id $CHAIN_ID --node $INJ_URL --keyring-backend=test

echo ""
