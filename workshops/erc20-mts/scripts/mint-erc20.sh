#!/bin/sh

set -e

source .local.env
source scripts/foundry-util.sh

if [ -z "$ERC20_CONTRACT" ]; then
    echo "Please set ERC20_CONTRACT to the deployed MintBurnBankERC20 contract address."
    exit 1
fi

USER_INJ_ADDRESS=$(injectived keys show $USER --keyring-backend=test -a)
USER_ETH_ADDRESS=0x$(injectived keys parse $USER_INJ_ADDRESS --output json | jq -r '.bytes')

echo "Injective address: $USER_INJ_ADDRESS"
echo "Ethereum address (owner): $USER_ETH_ADDRESS"

MINT_TO=${MINT_TO:-$USER_ETH_ADDRESS}
MINT_AMOUNT=${MINT_AMOUNT:-1000000000000000000000} # default: 1,000 tokens (18 decimals)

echo "Minting $MINT_AMOUNT tokens to $MINT_TO on contract $ERC20_CONTRACT..."

# Ensure MINT_TO is a valid 0x-prefixed address
if [ -z "$MINT_TO" ]; then
    echo "Error: MINT_TO is not set."
    exit 1
fi

if ! echo "$MINT_TO" | grep -Eq '^0x[0-9a-fA-F]{40}$'; then
    echo "Error: MINT_TO address '$MINT_TO' is not a valid 0x-prefixed Ethereum address."
    exit 1
fi

echo "\n### RUNNING ###"
echo cast send $ERC20_CONTRACT "mint(address,uint256)" "$MINT_TO" "$MINT_AMOUNT" \
    --rpc-url $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --gas-limit 1000000 \
    --gas-price 10 \
    --legacy \
    -vvvv \
    --json
echo "###############\n"

mint_res=$(cast send $ERC20_CONTRACT "mint(address,uint256)" "$MINT_TO" "$MINT_AMOUNT" \
    --rpc-url $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --gas-limit 1000000 \
    --gas-price 10 \
    --legacy \
    -vvvv \
    --json)
if [ $? -ne 0 ]; then
    echo "Mint failed"
    exit 1
fi

check_foundry_result "$mint_res"

echo "Minted $MINT_AMOUNT tokens to $MINT_TO on contract $ERC20_CONTRACT"
echo ""
