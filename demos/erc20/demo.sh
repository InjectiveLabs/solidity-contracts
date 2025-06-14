#!/bin/sh

################################################################################

. .local.env

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

echo "1) Importing user wallet..."
if cast wallet list | grep -q $USER; then
    echo "Wallet $USER already exists. Skipping import."
else
    cast wallet import $USER \
        --unsafe-password "$USER_PWD" \
        --mnemonic "$USER_MNEMONIC"
fi
user_inj_address=$(yes $USER_PWD | injectived keys show -a $USER)
user_eth_address=$(injectived q exchange eth-address-from-inj-address $user_inj_address)
echo "User INJ address: $user_inj_address"
echo "User ETH address: $user_eth_address"
echo ""

echo "2) Creating contract..."
create_res=$(forge create src/MintBurnBankERC20.sol:MintBurnBankERC20 \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --broadcast \
    --legacy \
    --gas-limit 10000000 \
    --gas-price 10 \
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

echo "3) Sending 1 INJ to the contract..."
yes 12345678 | injectived tx bank send user1 $contract_inj_address 1000000000000000000inj --gas 1000000 --gas-prices 10inj --chain-id injective-1 --yes
echo "OK"
echo ""

sleep 3

echo "3) Minting 666..."
mint_res=$(cast send \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --json \
    --legacy \
    --gas-limit 1000000 \
    --gas-price 10 \
    --value 1000000000000000000 \
    $contract_eth_address \
    "mint(address,uint256)" $user_eth_address 666)
if [ $? -ne 0 ]; then
    exit 1
fi
check_foundry_result "$mint_res"
echo "OK"
echo ""

# Query balances through cosmos x/bank
echo "4) Querying balances through cosmos x/bank..."
sleep 3
injectived q bank balances \
    --chain-id $CHAIN_ID \
    --node $INJ_URL \
    --output json \
    $user_inj_address \
    | jq -r '.balances[] | select(.denom == "'$denom'") | "\(.denom): \(.amount)"'
echo ""

# Query balances through EVM JSON-RPC
echo "5) Querying balances through EVM JSON-RPC..."
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
echo "6) Transfer 555..."
transfer_res=$(cast send \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --json \
    --legacy \
    --gas-limit 1000000 \
    --gas-price 10 \
    $contract_eth_address \
    "transfer(address,uint256)" 0x0b3D624F163F7135E1C5A7a777133e4126B96246 555)
if [ $? -ne 0 ]; then
    exit 1
fi
check_foundry_result "$transfer_res"
echo "OK"
echo ""


# Query balances through cosmos x/bank
echo "7) Querying balances through cosmos x/bank..."
sleep 3
injectived q bank balances \
    --chain-id $CHAIN_ID \
    --node $INJ_URL \
    --output json \
    $user_inj_address \
    | jq -r '.balances[] | select(.denom == "'$denom'") | "\(.denom): \(.amount)"'
echo ""

# Query balances through EVM JSON-RPC
echo "8) Querying balances through EVM JSON-RPC..."
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