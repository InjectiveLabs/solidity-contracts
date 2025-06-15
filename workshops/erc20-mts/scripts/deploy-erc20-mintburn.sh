#!/bin/sh

source .local.env
source scripts/foundry-util.sh

echo "Deploying ERC20 token..."

USER_INJ_ADDRESS=$(injectived keys show $USER --keyring-backend=test -a)
USER_ETH_ADDRESS=0x$(injectived keys parse $USER_INJ_ADDRESS --output json | jq -r '.bytes')

echo "Injective address: $USER_INJ_ADDRESS"
echo "Ethereum address (owner): $USER_ETH_ADDRESS"

echo "\n### RUNNING ###"
echo forge create src/MintBurnBankERC20.sol:MintBurnBankERC20 \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --broadcast \
    --value 1000000000000000000 \
    --gas-limit 10000000 \
    --gas-price 10 \
    --legacy \
    -vvvv \
    --json \
    --constructor-args $USER_ETH_ADDRESS "TestMeme" "MEME" "18"
echo "###############\n"

create_res=$(forge create src/MintBurnBankERC20.sol:MintBurnBankERC20 \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --broadcast \
    --value 1000000000000000000 \
    --gas-limit 10000000 \
    --gas-price 10 \
    --legacy \
    -vvvv \
    --json \
    --constructor-args $USER_ETH_ADDRESS "TestMeme" "MEME" "18")
if [ $? -ne 0 ]; then
    exit 1
fi
check_foundry_result "$create_res"

contract_eth_address=$(echo $create_res | jq -r '.deployedTo')
echo "ERC20 address: $contract_eth_address"
echo ""
