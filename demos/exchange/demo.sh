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
echo ""

echo "2) Creating contract..."

echo "\n### RUNNING ###"
echo forge create examples/ExchangeDemo.sol:ExchangeDemo \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --broadcast \
    --legacy \
    --gas-limit 10000000 \
    --gas-price 10 \
    -vvvv \
    --json
echo "###############\n"

create_res=$(forge create examples/ExchangeDemo.sol:ExchangeDemo \
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

contract_eth_address=$(echo $create_res | jq -r '.deployedTo')
contract_inj_address=$(injectived q exchange inj-address-from-eth-address $contract_eth_address)
contract_subaccount_id="$contract_eth_address"000000000000000000000001
echo "eth address: $contract_eth_address"
echo "inj address: $contract_inj_address"
echo ""

echo "3) Funding contract (100 USDT)..."

echo "\n### RUNNING ###"
echo injectived tx bank send \
    -y \
    --chain-id $CHAIN_ID \
    --node $INJ_URL \
    --fees 500000inj \
    --broadcast-mode sync \
    $USER \
    $contract_inj_address \
    1000000000000$QUOTE
echo "###############\n"

yes $USER_PWD | injectived tx bank send \
    -y \
    --chain-id $CHAIN_ID \
    --node $INJ_URL \
    --fees 500000inj \
    --broadcast-mode sync \
    $USER \
    $contract_inj_address \
    1000000000000$QUOTE
if [ $? -ne 0 ]; then
    exit 1
fi
echo ""

sleep 3

echo "\n### RUNNING ###"
echo injectived q bank balances \
    --chain-id $CHAIN_ID \
    --node $INJ_URL \
    $contract_inj_address
echo "###############\n"

injectived q bank balances \
    --chain-id $CHAIN_ID \
    --node $INJ_URL \
    $contract_inj_address
echo ""

echo "4) Calling contract.deposit..."

echo "\n### RUNNING ###"
echo cast send \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --json \
    --legacy \
    --gas-limit 1000000 \
    --gas-price 10 \
    $contract_eth_address \
    "deposit(string,string,uint256)" $contract_subaccount_id $QUOTE 1000000000
echo "###############\n"

deposit_res=$(cast send \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --json \
    --legacy \
    --gas-limit 1000000 \
    --gas-price 10 \
    $contract_eth_address \
    "deposit(string,string,uint256)" $contract_subaccount_id $QUOTE 1000000000)
if [ $? -ne 0 ]; then
    exit 1
fi
check_foundry_result "$deposit_res"
echo ""

sleep 3
echo "5) Querying contract deposits..."

echo "\n### RUNNING ###"
echo injectived q exchange deposits \
  --chain-id $CHAIN_ID \
  --node $INJ_URL \
  $contract_inj_address \
  1
echo "###############\n"

injectived q exchange deposits \
  --chain-id $CHAIN_ID \
  --node $INJ_URL \
  $contract_inj_address \
  1
echo ""

echo "6) Calling contract.withdraw..."

echo "\n### RUNNING ###"
echo cast send \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --json \
    --legacy \
    --gas-limit 1000000 \
    --gas-price 10 \
    $contract_eth_address \
    "withdraw(string,string,uint256)" $contract_subaccount_id $QUOTE 999
echo "###############\n"

withdraw_res=$(cast send \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --json \
    --legacy \
    --gas-limit 1000000 \
    --gas-price 10 \
    $contract_eth_address \
    "withdraw(string,string,uint256)" $contract_subaccount_id $QUOTE 999)
if [ $? -ne 0 ]; then
    exit 1
fi
check_foundry_result "$withdraw_res"
echo ""

echo "7) Querying contract deposits..."

echo "\n### RUNNING ###"
echo injectived q exchange deposits \
  --chain-id $CHAIN_ID \
  --node $INJ_URL \
  $contract_inj_address \
  1
echo "###############\n"

injectived q exchange deposits \
  --chain-id $CHAIN_ID \
  --node $INJ_URL \
  $contract_inj_address \
  1
echo ""

echo "8) Calling contract.createDerivativeLimitOrder..."

price=10000
margin=5000

echo "\n### RUNNING ###"
echo cast send \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --json \
    --legacy \
    --gas-limit 1000000 \
    --gas-price 10 \
    $contract_eth_address \
    "createDerivativeLimitOrder((string,string,string,uint256,uint256,string,string,uint256,uint256))" \
    '('"$MARKET_ID"','"$contract_subaccount_id"',"",'$price',1,"","buy",'$margin',0)'
echo "###############\n"

order_res=$(cast send \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --json \
    --legacy \
    --gas-limit 1000000 \
    --gas-price 10 \
    $contract_eth_address \
    "createDerivativeLimitOrder((string,string,string,uint256,uint256,string,string,uint256,uint256))" \
    '('"$MARKET_ID"','"$contract_subaccount_id"',"",'$price',1,"","buy",'$margin',0)')
if [ $? -ne 0 ]; then
    exit 1
fi
check_foundry_result "$order_res"
echo ""

echo "9) Querying contract orders via GRPC..."

echo "\n### RUNNING ###"
echo grpcurl -plaintext \
    -d '{"subaccount_id":"'$contract_subaccount_id'", "market_id":"'$MARKET_ID'"}' \
    $GRPC_URL \
    injective.exchange.v1beta1.Query/SubaccountOrders
echo "###############\n"

grpcurl -plaintext \
    -d '{"subaccount_id":"'$contract_subaccount_id'", "market_id":"'$MARKET_ID'"}' \
    $GRPC_URL \
    injective.exchange.v1beta1.Query/SubaccountOrders
echo ""

echo "10) Querying subaccount positions via GRPC..."

echo "\n### RUNNING ###"
echo grpcurl -plaintext \
    -d '{"subaccount_id":"'$contract_subaccount_id'"}' \
    $GRPC_URL \
    injective.exchange.v1beta1.Query/SubaccountPositions
echo "###############\n"

grpcurl -plaintext \
    -d '{"subaccount_id":"'$contract_subaccount_id'"}' \
    $GRPC_URL \
    injective.exchange.v1beta1.Query/SubaccountPositions
echo ""

echo "11) Call contract.subaccountPositions..."

echo "\n### RUNNING ###"
echo cast call \
    -r $ETH_URL \
    $contract_eth_address \
    "subaccountPositions(string)" $contract_subaccount_id \
    | xargs echo cast decode-abi "subaccountPositions(string)(IExchangeModule.DerivativePosition[])"
echo "###############\n"

cast call \
    -r $ETH_URL \
    $contract_eth_address \
    "subaccountPositions(string)" $contract_subaccount_id \
    | xargs cast decode-abi "subaccountPositions(string)(IExchangeModule.DerivativePosition[])"
echo ""