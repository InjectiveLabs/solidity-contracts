# Exchange Precompile Documentation

## Overview

The Exchange Precompile is a system smart contract available at a fixed address 
(`0x0000000000000000000000000000000000000065`). It provides Solidity developers 
with a native interface to interact with the exchange module of the underlying 
blockchain. Through this precompile, smart contracts can perform actions such 
as:

* Depositing and withdrawing funds
* Placing or cancelling spot and derivative orders
* Querying subaccount balances and positions
* Managing authorization grants

---

## Calling the Precompile: Direct vs. Proxy Access

There are two primary ways to call the Exchange Precompile:

### 1. **Direct Access (Self-Calling Contracts)**

The contract interacts with the precompile on its own behalf. This means the caller and the actor on the exchange module are the same.

Example:

```solidity
exchange.deposit(address(this), subaccountID, denom, amount);
```

This requires **no authorization grant**, because the contract is only managing its own funds and positions.

### 2. **Proxy Access (Calling on Behalf of Another User)**

A smart contract may be designed to act on behalf of other users. In this pattern, the contract calls the precompile using a third-party's address as the sender.

Example:

```solidity
exchange.deposit(userAddress, subaccountID, denom, amount);
```

In this case, the smart contract must be **authorized** by the user (`userAddress`) to perform that action. Authorization is handled using the `approve` and `revoke` methods provided by the precompile.

To authorize a contract to perform specific actions:

```solidity
exchange.approve(grantee, msgTypes, spendLimit, duration);
```

To revoke that authorization:

```solidity
exchange.revoke(grantee, msgTypes);
```

You can check an existing authorization with:

```solidity
exchange.allowance(grantee, granter, msgType);
```

---

## Example: Direct Method

The following `ExchangeDemo` contract is an example of a smart-contract that uses
the direct access method to perform the basic exchange actions, `deposit`, 
`withdraw`, `createDerivativeLimitOrder`, as well as query `subaccountPositions`,
with its own funds.

```
// SPDX-License-Identifier: MIT
pragma solidity >0.6.6;

import "./Exchange.sol";
import "./ExchangeTypes.sol";

contract ExchangeDemo {
    address constant exchangeContract = 0x0000000000000000000000000000000000000065;
    IExchangeModule exchange = IExchangeModule(exchangeContract);

    /***************************************************************************
     * calling the precompile directly
    ****************************************************************************/

    // deposit funds into subaccount belonging to this contract
    function deposit(
        string calldata subaccountID,
        string calldata denom,
        uint256 amount
    ) external returns (bool) {
        return exchange.deposit(address(this), subaccountID, denom, amount);
    }

    // withdraw funds from a subaccount belonging to this contract
    function withdraw(
        string calldata subaccountID,
        string calldata denom,
        uint256 amount
    ) external returns (bool) {
         return exchange.withdraw(address(this), subaccountID, denom, amount);
    }

    function subaccountPositions(
        string calldata subaccountID
    ) external view returns (IExchangeModule.DerivativePosition[] memory positions) {
        return exchange.subaccountPositions(subaccountID);
    }

    function createDerivativeLimitOrder(
        IExchangeModule.DerivativeOrder calldata order
    ) external returns (IExchangeModule.CreateDerivativeLimitOrderResponse memory response) {
        try exchange.createDerivativeLimitOrder(address(this), order) returns (IExchangeModule.CreateDerivativeLimitOrderResponse memory resp) {
            return resp;
        } catch {
            revert("error creating derivative limit order");
        }
    }
}
```

The following script shows how one might deploy and interact with this 
smart-contract. For a full explanation of how to run this script please refer to
the full [demo](demo/exchange/README.md) in the solidity-contracts repo. 

```sh
#!/bin/sh

################################################################################

source .local.env

################################################################################

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
contract_eth_address=$(forge create src/ExchangeDemo.sol:ExchangeDemo \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    --broadcast \
    | awk -F ': ' '/Deployed/ {print $2}')
contract_inj_address=$(injectived q exchange inj-address-from-eth-address $contract_eth_address)
contract_subaccount_id="$contract_eth_address"000000000000000000000001
echo "eth address: $contract_eth_address"
echo "inj address: $contract_inj_address"
echo ""

echo "3) Funding contract..."
# send 100 * 10^18 inj to the contract
yes $USER_PWD | injectived tx bank send \
    -y \
    --chain-id $CHAIN_ID \
    --node $INJ_URL \
    --fees 50000inj \
    --broadcast-mode sync \
    $USER \
    $contract_inj_address \
    1000000000000$QUOTE
echo ""

sleep 3
injectived q bank balances \
    --chain-id $CHAIN_ID \
    --node $INJ_URL \
    $contract_inj_address
echo ""

echo "4) Calling contract.depotit..."
cast send \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    $contract_eth_address \
    "deposit(string,string,uint256)" $contract_subaccount_id $QUOTE 1000000000
echo ""

echo "5) Querying contract deposits..."
injectived q exchange deposits \
  --chain-id $CHAIN_ID \
  --node $INJ_URL \
  $contract_inj_address \
  1
echo ""

echo "6) Calling contract.withdraw..."
cast send \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    $contract_eth_address \
    "withdraw(string,string,uint256)" $contract_subaccount_id $QUOTE 999
echo ""

echo "7) Querying contract deposits..."
injectived q exchange deposits \
  --chain-id $CHAIN_ID \
  --node $INJ_URL \
  $contract_inj_address \
  1
echo ""

echo "8) Calling contract.createDerivativeLimitOrder..."
price=10000
margin=5000
cast send \
    -r $ETH_URL \
    --account $USER \
    --password $USER_PWD \
    $contract_eth_address \
    "createDerivativeLimitOrder((string,string,string,uint256,uint256,string,string,uint256,uint256))" \
    '('"$MARKET_ID"','"$contract_subaccount_id"',"",'$price',1,"","buy",'$margin',0)'
echo ""

echo "9) Querying contract orders..."
grpcurl -plaintext \
    -d '{"subaccount_id":"'$contract_subaccount_id'", "market_id":"'$MARKET_ID'"}' \
    $GRPC_URL \
    injective.exchange.v1beta1.Query/SubaccountOrders
echo ""

echo "10) Call contract.subaccountPositions..."
cast call \
    -r $ETH_URL \
    $contract_eth_address \
    "subaccountPositions(string)" $contract_subaccount_id \
    | xargs cast decode-abi "subaccountPositions(string)(IExchangeModule.DerivativePosition[])"
echo ""
```

## Example: Proxy Contract with Authorization

The following contract implements an `ExchangeProxy` that demonstrates how to 
use the exchange precompile using the proxy method to perform actions on behalf
of a caller.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity >0.6.6;

import "./Exchange.sol";
import "./CosmosTypes.sol";
import "./ExchangeTypes.sol";

contract ExchangeProxy {
    address constant exchangeContract = 0x0000000000000000000000000000000000000065;
    IExchangeModule exchange = IExchangeModule(exchangeContract);

    /// @dev Approves a message type, so that this contract can submit it on 
    /// behalf of the origin. 
    /// @param msgType The type of the message to approve.
    /// @param spendLimit The spend limit for the message type.
    /// @param duration The time period for which the authorization is valid (in seconds).
    /// @return success Boolean value to indicate if the approval was successful.
    function approve(
        ExchangeTypes.MsgType msgType,
        Cosmos.Coin[] memory spendLimit,
        uint256 duration
    ) external returns (bool success) {
        ExchangeTypes.MsgType[] memory methods = new ExchangeTypes.MsgType[](1);
        methods[0] = msgType;
        
        try exchange.approve(address(this), methods, spendLimit, duration) returns (bool approved) {
            return approved;
        } catch {
            revert("error approving msg with spend limit");
        }
    }

    /// @dev Revokes a grant from the origin to this contract for a specific method
    /// @param msgType The type of the message to revoke.
    /// @return success Boolean value to indicate if the revocation was successful.
    function revoke(ExchangeTypes.MsgType msgType) external returns (bool success) {
        ExchangeTypes.MsgType[] memory methods = new ExchangeTypes.MsgType[](1);
        methods[0] = msgType;

        try exchange.revoke(address(this), methods) returns (bool revoked) {
            return revoked;
        } catch {
            revert("error revoking method");
        }
    }

    /// @dev Creates a derivative limit order on behalf of the specified sender. 
    /// It will revert with an error if this smart-contract doesn't have a grant 
    /// from the sender to perform this action on their behalf. 
    /// cf approveCreateDerivativeLimitOrder for granting authorization
    /// @param sender The address of the sender.
    /// @param order The derivative order to create.
    /// @return response The response from the createDerivativeLimitOrder call.
    function createDerivativeLimitOrder(
        address sender,
        IExchangeModule.DerivativeOrder calldata order
    ) external returns (IExchangeModule.CreateDerivativeLimitOrderResponse memory response) {
        try exchange.createDerivativeLimitOrder(sender, order) returns (IExchangeModule.CreateDerivativeLimitOrderResponse memory resp) {
            return resp;
        } catch {
            revert("error creating derivative limit order");
        }
    }

    /// @dev Queries whether a specific msgType is currently authorized
    /// from granter to grantee.
    function queryAllowance(
        address grantee,
        address granter, 
        ExchangeTypes.MsgType msgType
    ) external view returns (bool allowed) {
        try exchange.allowance(grantee, granter, msgType) returns (bool isAllowed) {
            return isAllowed;
        } catch {
            revert("error querying allowance");
        }
    }
}
```

## Conclusion

The Exchange Precompile enables rich, protocol-integrated trading logic to be 
embedded directly in smart contracts. Whether you're managing funds directly or 
acting as a broker for external users, it offers a clean and secure way to 
interact with the core exchange module using Solidity.

Use direct calls for your own contract logic. Use proxy patterns with `approve` 
and `revoke` if you're building reusable contract interfaces for other users.
