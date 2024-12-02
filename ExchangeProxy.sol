// SPDX-License-Identifier: MIT
pragma solidity >0.6.6;

import  "./Exchange.sol";
import "./CosmosTypes.sol";

contract ExchangeProxy {
    address constant exchangeContract = 0x0000000000000000000000000000000000000065;
    IExchangeModule exchange = IExchangeModule(exchangeContract);

   
    /// @dev Approves a message type, so that this contract can submit it on 
    //behalf of the origin. 
    /// @param msgType The type of the message to approve.
    /// @param spendLimit The spend limit for the message type URL.
    /// @return success Boolean value to indicate if the approval was successful.
    function approve(
        IExchangeModule.MsgType msgType,
        Cosmos.Coin[] memory spendLimit
    ) external returns (bool success) {
        IExchangeModule.MsgType[] memory methods = new IExchangeModule.MsgType[](1);
        methods[0] = msgType;

        try exchange.approve(address(this), methods, spendLimit) returns (bool approved) {
            return approved;
        } catch {
            revert("error approving msg with spend limit");
        }
    }

    /// @dev Revokes a grant from the origin to this contract for a specific method
    /// @param msgType The type of the message to revoke.
    /// @return success Boolean value to indicate if the revocation was successful.
    function revoke(IExchangeModule.MsgType msgType) external returns (bool success) {
        IExchangeModule.MsgType[] memory methods = new IExchangeModule.MsgType[](1);
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

    function queryAllowance(
        address grantee,
        address granter, 
        IExchangeModule.MsgType msgType
    ) external view returns (bool allowed) {
        try exchange.allowance(grantee, granter, msgType) returns (bool isAllowed) {
            return isAllowed;
        } catch {
            revert("error querying allowance");
        }
    }


}