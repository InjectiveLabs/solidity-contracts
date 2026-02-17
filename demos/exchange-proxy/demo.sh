#!/bin/sh

# Load environment variables
if [ -f ./.local.env ]; then
    source ./.local.env
else
    echo "Error: .local.env file not found"
    exit 1
fi

: ${INJ_HOME:=~/.injectived}
echo "User injectived home: $INJ_HOME"

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

check_injectived_result() {
    res=$1
    should_fail=$2

    # Extract transaction hash and check result
    tx_hash=$(echo $res | jq -r '.txhash')

    sleep 3s

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
echo ""
user_inj_address=$(yes $USER_PWD | injectived --home $INJ_HOME keys show -a $USER)
user_eth_address=$(injectived q exchange eth-address-from-inj-address $user_inj_address)
user_subaccount_id="$user_eth_address"000000000000000000000001
echo "User INJ address: $user_inj_address"
echo "User ETH address: $user_eth_address"
echo "User subaccount ID: $user_subaccount_id"
echo ""

echo "2) Depositing funds to user subaccount..."
# deposit 1000 USDT into the user's subaccount
deposit_res=$(yes 12345678 | injectived tx exchange deposit 1000000000$QUOTE $user_subaccount_id \
    --chain-id $CHAIN_ID \
    --home $INJ_HOME \
    --from $USER \
    --fees 500000inj \
    --output json \
    --broadcast-mode sync \
    -y)
if [ $? -ne 0 ]; then
    exit 1
fi
check_injectived_result "$deposit_res" false
echo "OK"
echo ""

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
# spend-limit: 300 USDT (USDT has 6 decimals)
# duration: 1 hour
authorizations="[(8,[(300000000,peggy0xdAC17F958D2ee523a2206206994597C13D831ec7)],3600)]"

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
# create a derivative limit order in INJ/USDT perp market, with:
# numbers are in API FORMAT, human-readable with 18 decimals
# Oracle mark price is ~1.461, so use prices close to that
# quantity 125.75 INJ (125750000000000000000) 
# price 1.45 USDT (1450000000000000000) - slightly below mark price for buy order
# margin: 10.5 USDT (10500000000000000000) - notional is 182.3375, min margin ~9.12, using 10.5 for safety
# Note that the margin, which is roughly the amount that would be taken from the
# user's deposit if this transaction goes through (aka the "hold"), is covered by
# the 300 USDT grant created above
market_id="0x7cc8b10d7deb61e744ef83bdec2bbcf4a056867e89b062c6a453020ca82bd4e4" # INJ/USDT
user_subaccount_id="$user_eth_address"000000000000000000000001
quantity=125750000000000000000
price=1450000000000000000
margin=10500000000000000000
fee_recipient='""'
cid='""'
order_type="buy"
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


echo "7) Query grants again..."
injectived q authz grants-by-grantee $contract_inj_address
echo ""