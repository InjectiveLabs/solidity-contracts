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
echo "User INJ address: $user_inj_address"
echo "User ETH address: $user_eth_address"
echo ""

echo "2) Creating contract..."
create_res=$(forge create src/tests/StakingTest.sol:StakingTest \
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

echo "3) Funding contract..."
# send 100 * 10^18 inj to the contract
yes $USER_PWD | injectived tx bank send \
    -y \
    --home $INJ_HOME \
    --chain-id $CHAIN_ID \
    --node $INJ_URL \
    --fees 500000inj \
    --broadcast-mode sync \
    $USER \
    $contract_inj_address \
    100000000000000000000inj
if [ $? -ne 0 ]; then
    exit 1
fi
echo ""

sleep 3
injectived q bank balances \
    --chain-id $CHAIN_ID \
    --node $INJ_URL \
    $contract_inj_address
echo ""

validator=$(injectived q staking validators | awk '/operator_address:/ {print $2}')
echo "validator: $validator"
echo ""

echo "4) Calling contract.delegate..."
delegate_res=$(cast send \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --json \
    --legacy \
    --gas-limit 1000000 \
    --gas-price 10 \
    $contract_eth_address \
    "delegate(string,uint256)" $validator  $DELEGATION_AMOUNT)
if [ $? -ne 0 ]; then
    exit 1
fi
check_foundry_result "$delegate_res"
echo ""

sleep 2

echo "5) Querying contract delegations through staking module..."
injectived q staking delegation \
    --chain-id $CHAIN_ID \
    --node $INJ_URL \
    $contract_inj_address \
    $validator
echo ""

echo "6) Querying contract delegations through staking precompile..."
cast call \
    -r $ETH_URL \
    $contract_eth_address \
    "delegation(address,string)" $contract_eth_address $validator \
    | xargs cast decode-abi "delegation(address,string)(uint256,(uint256,string))"
echo ""

echo "7) Calling contract.undelegate..."
withdraw_res=$(cast send \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --json \
    --legacy \
    --gas-limit 1000000 \
    --gas-price 10 \
    $contract_eth_address \
    "undelegate(string,uint256)" $validator 25000000000000000000)
if [ $? -ne 0 ]; then
    exit 1
fi
check_foundry_result "$withdraw_res"
echo ""

echo "8) Querying contract undelegations through staking module..."
injectived q staking delegation \
    --chain-id $CHAIN_ID \
    --node $INJ_URL \
    $contract_inj_address \
    $validator
echo ""

echo "9) Calling contract.withdrawDelegatorRewards..."
withdraw_res=$(cast send \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --json \
    --legacy \
    --gas-limit 1000000 \
    --gas-price 10 \
    $contract_eth_address \
    "withdrawDelegatorRewards(string)" $validator)
if [ $? -ne 0 ]; then
    exit 1
fi
check_foundry_result "$withdraw_res"
echo ""

echo "10) Querying contract balance again..."
injectived q bank balances \
    --chain-id $CHAIN_ID \
    --node $INJ_URL \
    $contract_inj_address
echo ""

