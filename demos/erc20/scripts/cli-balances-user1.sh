#!/bin/sh

source .local.env

echo "Checking balance of user1..."

USER_INJ_ADDRESS=$(injectived keys show $USER --keyring-backend=test -a)

echo "\n### RUNNING ###"
echo injectived q bank balances $USER_INJ_ADDRESS --chain-id $CHAIN_ID --node $INJ_URL
echo "###############\n"

injectived q bank balances $USER_INJ_ADDRESS --chain-id $CHAIN_ID --node $INJ_URL

echo ""
