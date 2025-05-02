#!/bin/sh

CONTRACT_ETH_ADDRESS=$(awk '{print $1}' contract-address.txt)

injectived q bank balances \
    --chain-id $CHAIN_ID \
    --node $INJ_URL \
    $(injectived q exchange inj-address-from-eth-address $CONTRACT_ETH_ADDRESS)

