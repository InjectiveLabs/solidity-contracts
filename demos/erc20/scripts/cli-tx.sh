#!/bin/sh

source .local.env

injectived tx $* --keyring-backend=test --chain-id $CHAIN_ID --node $INJ_URL --gas=auto --gas-adjustment=1.3 --gas-prices=10inj

echo ""
