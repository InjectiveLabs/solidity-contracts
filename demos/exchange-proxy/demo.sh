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
user_inj_address=$(yes $USER_PWD | injectived keys show -a $USER)
user_eth_address=$(injectived q exchange eth-address-from-inj-address $user_inj_address)
user_subaccount_id="$user_eth_address"000000000000000000000001
echo "User INJ address: $user_inj_address"
echo "User ETH address: $user_eth_address"
echo "User subaccount ID: $user_subaccount_id"
echo ""

echo "2) Depositing funds to user subaccount..."
yes 12345678 | injectived tx exchange deposit 2000000000000$QUOTE $user_subaccount_id \
    --chain-id $CHAIN_ID \
    --from $USER \
    --fees 500000inj \
    -y
echo ""

sleep 3s

echo "3) Creating contract..."
create_res=$(forge create src/tests/ExchangeProxy.sol:ExchangeProxy \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --gas-limit $GAS_LIMIT \
    --gas-price $GAS_PRICE \
    --broadcast \
    --legacy \
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

echo "4) Granting authorization..."
# createDerivativeLimitOrder
# spend-limit: 1000000 USDT (quote-decimals are 0 for this market, as can be 
# attested by running `injectived q exchange derivative-market $MARKET_ID`)
# duration: 1 hour
authorizations="[(8,[(1000000,peggy0xdAC17F958D2ee523a2206206994597C13D831ec7)],3600)]"

authz_res=$(cast send \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --gas-limit $GAS_LIMIT \
    --gas-price $GAS_PRICE \
    --json \
    --legacy \
    $EXCHANGE_PRECOMPILE \
    "approve(address,(uint8,(uint256,string)[],uint256)[])" $contract_eth_address $authorizations)
if [ $? -ne 0 ]; then
    exit 1
fi
check_foundry_result "$authz_res"
echo "OK"
echo ""

injectived q authz grants-by-grantee $contract_inj_address
echo ""

echo "5) calling proxy createDerivativeLimitOrder..."

market_id="0x7cc8b10d7deb61e744ef83bdec2bbcf4a056867e89b062c6a453020ca82bd4e4" # INJ/USDT
user_subaccount_id="$user_eth_address"000000000000000000000001
fee_recipient='""'
price=20000
quantity=100 
cid='""'
order_type="buy"
margin=1000000 
trigger_price=0

authz_res=$(cast send \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --gas-limit $GAS_LIMIT \
    --gas-price $GAS_PRICE \
    --json \
    --legacy \
    $contract_eth_address \
    "createDerivativeLimitOrder(address,(string,string,string,uint256,uint256,string,string,uint256,uint256))" \
    $user_eth_address "($market_id,$user_subaccount_id,$fee_recipient,$price,$quantity,$cid,$order_type,$margin,$trigger_price)")
if [ $? -ne 0 ]; then
    exit 1
fi
check_foundry_result "$authz_res"
echo "OK"
echo ""

echo "6) Querying user orders..."
grpcurl -plaintext \
    -d '{"subaccount_id":"'$user_subaccount_id'", "market_id":"'$market_id'"}' \
    $GRPC_URL \
    injective.exchange.v1beta1.Query/SubaccountOrders
echo ""

injectived q authz grants-by-grantee $contract_inj_address
echo ""