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

echo "2) Creating contract..."
create_res=$(forge create examples/ExchangeDemo.sol:ExchangeDemo \
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
echo "subaccount id: $contract_subaccount_id"
echo ""

echo "3) Funding contract..."
# send 5000  USDT to the contract (equal to 5000*10^6 usdt because USDT has 6 decimals)
fund_res=$(yes $USER_PWD | injectived tx bank send \
    -y \
    --home $INJ_HOME \
    --chain-id $CHAIN_ID \
    --node $INJ_URL \
    --fees 500000inj \
    --broadcast-mode sync \
    --output json \
    $USER \
    $contract_inj_address \
    5000000000$QUOTE)
if [ $? -ne 0 ]; then
    exit 1
fi
check_injectived_result "$fund_res" false
echo ""


injectived q bank balances \
    --chain-id $CHAIN_ID \
    --node $INJ_URL \
    $contract_inj_address
echo ""

echo "4) Calling contract.deposit..."
# depost 1000 USDT into the contract's default exchange subaccount
deposit_res=$(cast send \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --gas-limit $GAS_LIMIT \
    --gas-price $GAS_PRICE \
    --json \
    --legacy \
    $contract_eth_address \
    "deposit(string,string,uint256)" $contract_subaccount_id $QUOTE 1000000000)
if [ $? -ne 0 ]; then
    exit 1
fi
check_foundry_result "$deposit_res"
echo "OK"
echo ""

echo "5) Querying contract deposits..."
injectived q exchange deposits \
  --chain-id $CHAIN_ID \
  --node $INJ_URL \
  $contract_inj_address \
  1
echo ""

echo "6) Calling contract.withdraw..."
# withdraw 500 USDT from the contract's exchange subaccount
withdraw_res=$(cast send \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --gas-limit $GAS_LIMIT \
    --gas-price $GAS_PRICE \
    --json \
    --legacy \
    $contract_eth_address \
    "withdraw(string,string,uint256)" $contract_subaccount_id $QUOTE 500000000)
if [ $? -ne 0 ]; then
    exit 1
fi
check_foundry_result "$withdraw_res"
echo "OK"
echo ""

echo "7) Querying contract deposits..."
injectived q exchange deposits \
  --chain-id $CHAIN_ID \
  --node $INJ_URL \
  $contract_inj_address \
  1
echo ""

echo "8) Calling contract.createDerivativeLimitOrder..."
# create a buy order on the INJ/USDT derivative market with following properties:
# numbers are in API FORMAT, human-readable with 18 decimals
# Oracle mark price is ~1.461, so use prices close to that
# quantity 125.75 INJ (125750000000000000000) 
# price 1.45 USDT (1450000000000000000) - slightly below mark price for buy order
# margin: 10.5 USDT (10500000000000000000) - notional is 182.3375, min margin ~9.12, using 10.5 for safety
quantity=125750000000000000000
price=1450000000000000000
margin=10500000000000000000
order_res=$(cast send \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --gas-limit $GAS_LIMIT \
    --gas-price $GAS_PRICE \
    --json \
    --legacy \
    $contract_eth_address \
    "createDerivativeLimitOrder((string,string,string,uint256,uint256,string,string,uint256,uint256))" \
    '('"$MARKET_ID"','"$contract_subaccount_id"',"",'$price','$quantity',"","buy",'$margin','$price')')
if [ $? -ne 0 ]; then
    exit 1
fi
check_foundry_result "$order_res"
echo "OK"
echo ""

echo "9) Querying contract orders..."
grpcurl -plaintext \
    -d '{"subaccount_id":"'$contract_subaccount_id'", "market_id":"'$MARKET_ID'"}' \
    $GRPC_URL \
    injective.exchange.v1beta1.Query/TraderDerivativeOrders
echo ""

echo "10) Querying contract deposits..."
injectived q exchange deposits \
  --chain-id $CHAIN_ID \
  --node $INJ_URL \
  $contract_inj_address \
  1
echo ""json