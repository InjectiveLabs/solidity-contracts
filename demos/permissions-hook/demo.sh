#!/bin/sh

################################################################################

source ./.local.env

################################################################################

check_foundry_result() {
    res=$1

    eth_tx_hash=$(echo $res | jq -r '.transactionHash')
    sdk_tx_hash=$(cast rpc inj_getTxHashByEthHash $eth_tx_hash | sed -r 's/0x//' | tr -d '"')

    tx_receipt=$(injectived q tx $sdk_tx_hash --node $INJ_URL --output json)
    code=$(echo $tx_receipt | jq -r '.code')
    raw_log=$(echo $tx_receipt | jq -r '.raw_log')

    if [ $code -ne 0 ]; then
        echo "Error: Tx Failed. Code: $code, Log: $raw_log"
        exit 1
    fi
}

check_injectived_result() {
    res=$1
    should_fail=$2

    # Extract transaction hash and check result
    tx_hash=$(echo $res | jq -r '.txhash')

    sleep 3

    # Check transaction result
    tx_result=$(injectived q tx $tx_hash --node $INJ_URL --output json)
    code=$(echo $tx_result | jq -r '.code')
    raw_log=$(echo $tx_result | jq -r '.raw_log')

    if [ $code -ne 0 ]; then
        echo "Error: Tx Failed. Code: $code, Log: $raw_log"
        if [ "$should_fail" = "false" ]; then
            exit 1
        fi
    fi

    if [ "$should_fail" = "true" ] && [ $code -eq 0 ]; then
        echo "Tx was expected to fail but succeeded"
        exit 1
    fi
}

echo "1) Importing user wallet..."
if cast wallet list | grep -q $USER; then
    echo "Wallet $USER already exists. Skipping import."
else
    cast wallet import $USER \
        --unsafe-password "$USER_PWD" \
        --mnemonic "$USER_MNEMONIC"
fi
user_inj_address=$(yes $USER_PWD | injectived --home $INJHOME keys show -a $USER)
user_eth_address=$(injectived q exchange eth-address-from-inj-address $user_inj_address)
echo "User INJ address: $user_inj_address"
echo "User ETH address: $user_eth_address"
echo ""

echo "2) Creating erc20 contract..."
create_res=$(forge create src/MintBurnBankERC20.sol:MintBurnBankERC20 \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --broadcast \
    --legacy \
    --gas-limit 10000000 \
    --gas-price 10 \
    --value 1000000000000000000 \
    -vvvv \
    --json \
    --constructor-args $user_eth_address "DemoMintBurnERC20" "DMB" 18)
if [ $? -ne 0 ]; then
    exit 1
fi
check_foundry_result "$create_res"

contract_eth_address=$(echo $create_res | jq -r '.deployedTo')
contract_inj_address=$(injectived q exchange inj-address-from-eth-address $contract_eth_address)
denom="erc20:$contract_eth_address"
echo "Contract ETH address: $contract_eth_address"
echo "Contract INJ address: $contract_inj_address"
echo "Denom: $denom"
echo ""

echo "3) Creating hook contract..."
create_res=$(forge create examples/PermissionsHookExamples.sol:RestrictSpecificAddressTransferHook \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --broadcast \
    --legacy \
    --gas-limit 10000000 \
    --gas-price 10 \
    -vvvv \
    --json)
if [ $? -ne 0 ]; then
    exit 1
fi
check_foundry_result "$create_res"

hook_eth_address=$(echo $create_res | jq -r '.deployedTo')
hook_inj_address=$(injectived q exchange inj-address-from-eth-address $hook_eth_address)
echo "Hook ETH address: $hook_eth_address"
echo "Hook INJ address: $hook_inj_address"
echo ""

# Fill the namespace template with actual values
sed -e "s/\[DENOM\]/$denom/g" \
    -e "s/\[EVM_HOOK\]/$hook_eth_address/g" \
    -e "s/\[ADMIN\]/$user_inj_address/g" \
    namespace_template.json > namespace_filled.json


# Create the namespace using the filled template
echo "4) Creating namespace from unauthorized user (SHOULD FAIL)..."
create_namespace_res=$(echo 12345678 | injectived tx permissions create-namespace \
    --home $INJHOME \
    --from user2 \
    --chain-id $CHAIN_ID \
    --node $INJ_URL \
    --gas 300000 \
    --fees 500000inj \
    --broadcast-mode sync \
    --yes \
    --output json \
    namespace_filled.json)
if [ $? -ne 0 ]; then
    echo "Error creating namespace: $create_namespace_res"
    exit 1
fi
check_injectived_result "$create_namespace_res" true
echo "Failed as expected"
echo ""

echo "4 bis) Creating namespace from owner of ERC20 token (SHOULD SUCCEED)..."
create_namespace_res=$(echo 12345678 | injectived tx permissions create-namespace \
    --home $INJHOME \
    --from $USER \
    --chain-id $CHAIN_ID \
    --node $INJ_URL \
    --gas 300000 \
    --fees 500000inj \
    --broadcast-mode sync \
    --yes \
    --output json \
    namespace_filled.json)
if [ $? -ne 0 ]; then
    echo "Error creating namespace: $create_namespace_res"
    exit 1
fi
check_injectived_result "$create_namespace_res" false
echo "OK"
echo ""

echo "5) Minting 666..."
mint_res=$(cast send \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --json \
    --legacy \
    --gas-limit 1000000 \
    --gas-price 10 \
    $contract_eth_address \
    "mint(address,uint256)" $user_eth_address 666)
if [ $? -ne 0 ]; then
    exit 1
fi
check_foundry_result "$mint_res"
echo "OK"
echo ""

# Query balances through cosmos x/bank
echo "6) Querying balances through cosmos x/bank..."
sleep 3
injectived q bank balances \
    --chain-id $CHAIN_ID \
    --node $INJ_URL \
    --output json \
    $user_inj_address \
    | jq -r '.balances[] | select(.denom == "'$denom'") | "\(.denom): \(.amount)"'
echo ""

# Query balances through EVM JSON-RPC
echo "7) Querying balances through EVM JSON-RPC..."
hexbal=$(cast call \
    -r $ETH_URL \
    $contract_eth_address \
    "balanceOf(address)" $user_eth_address)
if [ $? -ne 0 ]; then
    exit 1
fi
bal=$(printf "%d" $hexbal)
echo "$denom: $bal"
echo ""

# Transfer
echo "8) Transfer 55 to authorized address..."
transfer_res=$(cast send \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --json \
    --legacy \
    --gas-limit 1000000 \
    --gas-price 10 \
    $contract_eth_address \
    "transfer(address,uint256)" 0x0b3D624F163F7135E1C5A7a777133e4126B96246 55)
if [ $? -ne 0 ]; then
    exit 1
fi
check_foundry_result "$transfer_res"
echo "OK"
echo ""


# Query balances through cosmos x/bank
echo "9) Querying balances through cosmos x/bank..."
sleep 3
injectived q bank balances \
    --chain-id $CHAIN_ID \
    --node $INJ_URL \
    --output json \
    $user_inj_address \
    | jq -r '.balances[] | select(.denom == "'$denom'") | "\(.denom): \(.amount)"'
echo ""

# Query balances through EVM JSON-RPC
echo "10) Querying balances through EVM JSON-RPC..."
hexbal=$(cast call \
    -r $ETH_URL \
    $contract_eth_address \
    "balanceOf(address)" $user_eth_address)
if [ $? -ne 0 ]; then
    exit 1
fi
bal=$(printf "%d" $hexbal)
echo "$denom: $bal"
echo ""

# Transfer
echo "11) Transfer 88 to unauthorized address..."
transfer_res=$(cast send \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --json \
    --legacy \
    --gas-limit 1000000 \
    --gas-price 10 \
    $contract_eth_address \
    "transfer(address,uint256)" 0x963EBDf2e1f8DB8707D05FC75bfeFFBa1B5BaC17 88)
if [ $? -ne 0 ]; then
    exit 1
fi
check_foundry_result "$transfer_res"
echo "OK"
echo ""


# Query balances through cosmos x/bank
echo "12) Querying balances through cosmos x/bank..."
sleep 3
injectived q bank balances \
    --chain-id $CHAIN_ID \
    --node $INJ_URL \
    --output json \
    $user_inj_address \
    | jq -r '.balances[] | select(.denom == "'$denom'") | "\(.denom): \(.amount)"'
echo ""

# Query balances through EVM JSON-RPC
echo "13) Querying balances through EVM JSON-RPC..."
hexbal=$(cast call \
    -r $ETH_URL \
    $contract_eth_address \
    "balanceOf(address)" $user_eth_address)
if [ $? -ne 0 ]; then
    exit 1
fi
bal=$(printf "%d" $hexbal)
echo "$denom: $bal"
echo ""
