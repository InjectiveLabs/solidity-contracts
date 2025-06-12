#!/bin/sh

source .local.env
source scripts/foundry-util.sh

echo "Deploying ERC20 token..."

echo "\n### RUNNING ###"
echo forge create src/FixedSupplyBankERC20.sol:FixedSupplyBankERC20 \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --broadcast \
    --gas-limit 10000000 \
    --gas-price 10 \
    --legacy \
    -vvvv \
    --json \
    --constructor-args "TestMeme" "MEME" "18" "1000000000000000000000000000"
echo "###############\n"

create_res=$(forge create src/FixedSupplyBankERC20.sol:FixedSupplyBankERC20 \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --broadcast \
    --gas-limit 10000000 \
    --gas-price 10 \
    --legacy \
    -vvvv \
    --json \
    --constructor-args "TestMeme" "MEME" "18" "1000000000000000000000000000")
if [ $? -ne 0 ]; then
    exit 1
fi
check_foundry_result "$create_res"

contract_eth_address=$(echo $create_res | jq -r '.deployedTo')
echo "ERC20 address: $contract_eth_address"
echo ""
