#!/bin/sh

CONTRACT_ETH_ADDRESS=$(awk '{print $1}' contract-address.txt)
nonce_part=000000000000000000000001
CONTRACT_SUBACCOUNT_ID=$CONTRACT_ETH_ADDRESS$nonce_part

cast send \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    $CONTRACT_ETH_ADDRESS \
    "withdraw(string,string,uint256)" $CONTRACT_SUBACCOUNT_ID $QUOTE 1 \
    -vvvv
