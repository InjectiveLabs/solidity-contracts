// SPDX-License-Identifier: MIT
pragma solidity >0.6.6;

import {IExchangeModule, MSG_CREATE_DERIVATIVE_LIMIT_ORDER} from "./Exchange.sol";

contract TestExchange {
    address constant exchangeContract = 0x0000000000000000000000000000000000000065;
    IExchangeModule exchange = IExchangeModule(exchangeContract);

    function deposit(
        string memory subaccountID,
        string memory denom,
        uint256 amount
    ) external returns (bool) {
        return exchange.deposit(address(this), subaccountID, denom, amount);
    }

    function delegateDeposit(
        string memory subaccountID,
        string memory denom,
        uint256 amount
    ) external returns (bool) {
        (bool success,) = exchangeContract.delegatecall(abi.encodeWithSignature("deposit(string,string,string,uint256)", address(this), subaccountID, denom, amount));
        return success;
    }

    function withdraw(
        string memory subaccountID,
        string memory denom,
        uint256 amount
    ) external returns (bool) {
         return exchange.withdraw(address(this), subaccountID, denom, amount);
    }

    function createDerivativeLimitOrder(
        IExchangeModule.DerivativeOrder calldata order
    ) external returns (IExchangeModule.CreateDerivativeLimitOrderResponse memory response) {
        return exchange.createDerivativeLimitOrder(address(this), order);
    }

    function approveCreateDerivativeLimitOrder() external returns (bool success) {
        string[] memory methods = new string[](1);
        methods[0] = MSG_CREATE_DERIVATIVE_LIMIT_ORDER;

        try exchange.approve(address(this), methods) returns (bool approved) {
            return approved;
        } catch {
            revert("error approving createDerivativeLimitOrder msg");
        }
    }

    function createDerivativeLimitOrderAuthz(
        address sender,
        IExchangeModule.DerivativeOrder calldata order
    ) external returns (IExchangeModule.CreateDerivativeLimitOrderResponse memory response) {
        
        
        try exchange.createDerivativeLimitOrderAuthz(sender, order) returns (IExchangeModule.CreateDerivativeLimitOrderResponse memory resp) {
            return resp;
        } catch {
            revert("error creating derivative limit order");
        }
    }
}