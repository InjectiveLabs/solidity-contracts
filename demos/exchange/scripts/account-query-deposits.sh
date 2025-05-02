#!/bin/sh

set -eux

CONTRACT_ETH_ADDRESS=$(awk '{print $1}' contract-address.txt)
CONTRACT_INJ_ADDRESS=$(injectived q exchange inj-address-from-eth-address $CONTRACT_ETH_ADDRESS)

injectived q exchange deposits \
  --chain-id $CHAIN_ID \
  --node $INJ_URL \
  $CONTRACT_INJ_ADDRESS \
  1