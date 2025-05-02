#!/bin/sh

forge create src/ExchangeDemo.sol:ExchangeDemo \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --broadcast \
    | awk -F ': ' '/Deployed/ {print $2}' \
    > contract-address.txt
