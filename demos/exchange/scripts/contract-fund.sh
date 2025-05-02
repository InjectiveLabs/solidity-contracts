#!/bin/sh

CONTRACT_ETH_ADDRESS=$(awk '{print $1}' contract-address.txt)

# send 100 * 10^18 inj to the contract
yes $USER_PWD | injectived tx bank send \
    -y \
    --chain-id $CHAIN_ID \
    --node $INJ_URL \
    --fees 50000inj \
    --broadcast-mode sync \
    $USER \
    $(injectived q exchange inj-address-from-eth-address $CONTRACT_ETH_ADDRESS) \
    100000000000000000000inj
