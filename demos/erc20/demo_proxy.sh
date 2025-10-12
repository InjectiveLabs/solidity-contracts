#!/bin/bash

set -e

# Load environment variables
if [ -f ./.local.env ]; then
    source ./.local.env
else
    echo "Error: .local.env file not found"
    exit 1
fi

: ${INJ_HOME:=~/.injectived}
echo "User injectived home: $INJ_HOME"
# Throwaway address for dummy initialization
THROWAWAY_ADDRESS="0x0000000000000000000000000000000000000001"

################################################################################
# Helper functions
################################################################################

check_foundry_result() {
    res=$1

    eth_tx_hash=$(echo $res | jq -r '.transactionHash')
    sdk_tx_hash=$(cast rpc inj_getTxHashByEthHash $eth_tx_hash -r $ETH_URL | sed -r 's/0x//' | tr -d '"')

    tx_receipt=$(injectived q tx $sdk_tx_hash --node $INJ_URL --output json)
    code=$(echo $tx_receipt | jq -r '.code')
    raw_log=$(echo $tx_receipt | jq -r '.raw_log')

    if [ $code -ne 0 ]; then
        echo "Error: Tx Failed. Code: $code, Log: $raw_log"

        # Get detailed transaction trace for debugging
        echo "Getting transaction trace..."
        cast rpc debug_traceTransaction "[\"$eth_tx_hash\",{\"tracer\":\"callTracer\"}]" --raw -r $ETH_URL | jq
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
user_inj_address=$(yes $USER_PWD | injectived --home $INJ_HOME keys show -a $USER)
user_eth_address=$(injectived q exchange eth-address-from-inj-address $user_inj_address)
echo "User INJ address: $user_inj_address"
echo "User ETH address: $user_eth_address"
echo ""

echo "2) Deploying MintBurnERC20Upgradeable implementation..."
impl_res=$(forge create src/MintBurnBankERC20Upgradeable.sol:MintBurnBankERC20Upgradeable \
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
    echo "Error deploying implementation"
    echo "$impl_res"
    exit 1
fi

check_foundry_result "$impl_res"

impl_address=$(echo "$impl_res" | jq -r '.deployedTo')
echo "Implementation deployed at: $impl_address"
echo ""

# Step 3: Deploy FiatTokenProxy
echo "3) Deploying TransparentUpgradeableProxy..."
proxy_res=$(forge create lib/openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --broadcast \
    --legacy \
    --gas-limit 10000000 \
    --gas-price 10 \
    -vvvv \
    --json \
    --constructor-args $impl_address $user_eth_address 0x)

if [ $? -ne 0 ]; then
    echo "Error deploying proxy"
    exit 1
fi

check_foundry_result "$proxy_res"

proxy_address=$(echo "$proxy_res" | jq -r '.deployedTo')
proxy_admin_slot=$(cast storage $proxy_address 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103 -r $ETH_URL) # admin slot
proxy_admin_address=$(cast parse-bytes32-address $proxy_admin_slot) # admin slot
denom="erc20:$proxy_address"

echo "Proxy deployed at: $proxy_address"
echo "ProxyAdmin deployed at: $proxy_admin_address"
echo ""
# Step 7: Initialize proxy (V1)
echo "4) Initializing ERC20 through proxy..."
proxy_init_res=$(cast send $proxy_address \
    "initialize(address,string,string,uint8)" \
    $user_eth_address "BZZ_BbZz_bz" "BZz" 6 \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --legacy \
    --gas-limit 10000000 \
    --gas-price 10 \
    --value 1000000000000000000 \
    -vvvv \
    --json)

if [ $? -ne 0 ]; then
    echo "Error initializing proxy"
    exit 1
fi

check_foundry_result "$proxy_init_res"
echo "Proxy initialized"
echo ""

echo "5) Minting 666..."
mint_res=$(cast send \
    $proxy_address \
    "mint(address,uint256)" $user_eth_address 666 \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --json \
    --legacy \
    --gas-limit 1000000 \
    --gas-price 10 \
    -vvvv)
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
echo "6) Querying balances through EVM JSON-RPC..."
hexbal=$(cast call \
    -r $ETH_URL \
    $proxy_address \
    "balanceOf(address)" $user_eth_address)
if [ $? -ne 0 ]; then
    exit 1
fi
bal=$(printf "%d" $hexbal)
echo "$denom: $bal"
echo ""

transfer_and_check() {
    # Transfer
    echo "Transfer 111..."
    transfer_res=$(cast send \
        -r $ETH_URL \
        --account $USER \
        --password $USER_PWD \
        --json \
        --legacy \
        --gas-limit 1000000 \
        --gas-price 10 \
        $proxy_address \
        "transfer(address,uint256)" 0x0b3D624F163F7135E1C5A7a777133e4126B96246 111)
    if [ $? -ne 0 ]; then
        exit 1
    fi
    check_foundry_result "$transfer_res"
    echo "OK"
    echo ""


    # Query balances through cosmos x/bank
    echo "Querying balances through cosmos x/bank..."
    sleep 3
    injectived q bank balances \
        --chain-id $CHAIN_ID \
        --node $INJ_URL \
        --output json \
        $user_inj_address \
        | jq -r '.balances[] | select(.denom == "'$denom'") | "\(.denom): \(.amount)"'
    echo ""

    # Query balances through EVM JSON-RPC
    echo "Querying balances through EVM JSON-RPC..."
    hexbal=$(cast call \
        -r $ETH_URL \
        $proxy_address \
        "balanceOf(address)" $user_eth_address)
    if [ $? -ne 0 ]; then
        exit 1
    fi
    bal=$(printf "%d" $hexbal)
    echo "$denom: $bal"
    echo ""
}

echo "7) Transfer 111 and check..."
transfer_and_check

echo "8) Deploying 2nd MintBurnERC20Upgradeable implementation..."
impl2_res=$(forge create src/MintBurnBankERC20Upgradeable.sol:MintBurnBankERC20Upgradeable \
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
    echo "Error deploying implementation"
    echo "$impl2_res"
    exit 1
fi

check_foundry_result "$impl2_res"

impl2_address=$(echo "$impl2_res" | jq -r '.deployedTo')
echo "2nd implementation deployed at: $impl2_address"
echo ""

echo "9) Changing implementation inside Proxy..."
proxy_change_res=$(cast send $proxy_admin_address \
    "upgradeAndCall(address,address,bytes)" $proxy_address $impl2_address 0x \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --legacy \
    --gas-limit 10000000 \
    --gas-price 10 \
    -vvvv \
    --json)

if [ $? -ne 0 ]; then
    echo "Error changing proxy implementation"
    exit 1
fi

check_foundry_result "$proxy_change_res"
echo "Proxy implementation changed"
echo ""

echo "10) After implementation change, transfer again 111 and check..."
transfer_and_check

# Final summary
echo "========================================"
echo "Deployment Complete!"
echo "========================================"
echo ""
echo "Deployed Contracts:"
echo "  Implementation 1st:    $impl_address"
echo "  Implementation 2nd:    $impl2_address"
echo "  Proxy:                 $proxy_address"
echo "  ProxyAdmin:            $proxy_admin_address"
echo ""
echo "Addresses:"
echo "  Proxy Admin Owner:            $user_eth_address"