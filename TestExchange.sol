// SPDX-License-Identifier: MIT
pragma solidity >0.6.6;

import  "./Exchange.sol";

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

    // revoke a CreateDerivativeLimitOrder grant from the origin to this contract
    function revokeCreateDerivativeLimitOrder() external returns (bool success) {
        string[] memory methods = new string[](1);
        methods[0] = MSG_CREATE_DERIVATIVE_LIMIT_ORDER;

        try exchange.revoke(address(this), methods) returns (bool revoked) {
            return revoked;
        } catch {
            revert("error revoking createDerivativeLimitOrder msg");
        }
    }

    function getAllExchangeMethods() internal pure returns (string[] memory methods) {
        methods = new string[](17);
        methods[0] = MSG_DEPOSIT;
        methods[1] = MSG_WITHDRAW;
        methods[2] = MSG_SUBACCOUNT_TRANSFER;
        methods[3] = MSG_EXTERNAL_TRANSFER;
        methods[4] = MSG_INCREASE_POSITION_MARGIN;
        methods[5] = MSG_DECREASE_POSITION_MARGIN;
        methods[6] = MSG_BATCH_UPDATE_ORDERS;
        methods[7] = MSG_CREATE_DERIVATIVE_LIMIT_ORDER;
        methods[8] = MSG_BATCH_CREATE_DERIVATIVE_LIMIT_ORDERS;
        methods[9] = MSG_CREATE_DERIVATIVE_MARKET_ORDER;
        methods[10] = MSG_CANCEL_DERIVATIVE_ORDER;
        methods[11] = MSG_BATCH_CANCEL_DERIVATIVE_ORDERS;
        methods[12] = MSG_CREATE_SPOT_LIMIT_ORDER;
        methods[13] = MSG_BATCH_CREATE_SPOT_LIMIT_ORDERS;
        methods[14] = MSG_CREATE_SPOT_MARKET_ORDER;
        methods[15] = MSG_CANCEL_SPOT_ORDER;
        methods[16] = MSG_BATCH_CANCEL_SPOT_ORDERS;
        return methods;
    }

    function approveAll() external returns (bool success) {
        string[] memory methods = getAllExchangeMethods();

        try exchange.approve(address(this), methods) returns (bool approved) {
            return approved;
        } catch {
            revert("error approving exchange msgs");
        }
    }

    function revokeAll() external returns (bool success) {
        string[] memory methods = getAllExchangeMethods();

        try exchange.revoke(address(this), methods) returns (bool revoked) {
            return revoked;
        } catch {
            revert("error revoking exchange msgs");
        }
    }


    function queryAllowance(
        address grantee,
        address granter, 
        string calldata msgUrl
    ) external view returns (bool allowed) {
        try exchange.allowance(grantee, granter, msgUrl) returns (bool isAllowed) {
            return isAllowed;
        } catch {
            revert("error querying allowance");
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