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
pragma solidity ^0.8.4;

import "../src/Exchange.sol";
import "../src/ExchangeTypes.sol";

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
        try exchange.deposit(address(this), subaccountID, denom, amount) returns (bool success) {
            return success;
        } catch Error(string memory reason) {
            revert(string(abi.encodePacked("Deposit error: ", reason)));
        } catch {
            revert("Unknown error during deposit");
        }
    }

    // withdraw funds from a subaccount belonging to this contract
    function withdraw(
        string calldata subaccountID,
        string calldata denom,
        uint256 amount
    ) external returns (bool) {
        try exchange.withdraw(address(this), subaccountID, denom, amount) returns (bool success) {
            return success;
        } catch Error(string memory reason) {
            revert(string(abi.encodePacked("Withdraw error: ", reason)));
        } catch {
            revert("Unknown error during withdraw");
        }
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
        } catch Error(string memory reason) {
            revert(string(abi.encodePacked("CreateDerivativeLimitOrder error: ", reason)));
        } catch {
            revert("Unknown error during createDerivativeLimitOrder");
        }
    }
}
```

Please refer to the [demo](../demos/exchange/README.md) to see how to build, deploy,
and interact with this smart-contract.

## Conclusion

The Exchange Precompile enables rich, protocol-integrated trading logic to be 
embedded directly in smart contracts. Whether you're managing funds directly or 
acting as a broker for external users, it offers a clean and secure way to 
interact with the core exchange module using Solidity.

Use direct calls for your own contract logic. Use proxy patterns with `approve` 
and `revoke` if you're building reusable contract interfaces for other users.
