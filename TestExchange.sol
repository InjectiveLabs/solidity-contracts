// SPDX-License-Identifier: MIT
pragma solidity >0.6.6;

import {IExchangeModule, MSG_CREATE_DERIVATIVE_LIMIT_ORDER } from "./Exchange.sol";

contract TestExchange {
    address constant exchangeContract = 0x0000000000000000000000000000000000000065;
    IExchangeModule exchange = IExchangeModule(exchangeContract);

    // deposit funds into subaccount belonging to this contract
    function deposit(
        string memory subaccountID,
        string memory denom,
        uint256 amount
    ) external returns (bool) {
        return exchange.deposit(address(this), subaccountID, denom, amount);
    }

    // withdraw funds from a subaccount belonging to this contract
    function withdraw(
        string memory subaccountID,
        string memory denom,
        uint256 amount
    ) external returns (bool) {
         return exchange.withdraw(address(this), subaccountID, denom, amount);
    }

    // delegateDeposit attempts to call the precompile via delegateCall. This is
    // here for testing, and we expect any call to this method to return an 
    // error because the precompile doesn't support delegateCall. 
    function delegateDeposit(
        string memory subaccountID,
        string memory denom,
        uint256 amount
    ) external returns (bool) {
        (bool success,) = exchangeContract.delegatecall(abi.encodeWithSignature("deposit(string,string,string,uint256)", address(this), subaccountID, denom, amount));
        return success;
    }

    // create a grant, from the origin to this contract, so that this contract
    // can create derivative limit orders on behalf of the origin
    function approveCreateDerivativeLimitOrder() external returns (bool success) {
        string[] memory methods = new string[](1);
        methods[0] = MSG_CREATE_DERIVATIVE_LIMIT_ORDER;

        try exchange.approve(address(this), methods) returns (bool approved) {
            return approved;
        } catch {
            revert("error approving createDerivativeLimitOrder msg");
        }
    }

    // create a derivative limit order on behalf of the specified sender. It 
    // will return an error if this smart-contract doesn't have a grant from the
    // sender to perform this action on their behalf. 
    // cf approveCreateDerivativeLimitOrder for granting authorization
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
}