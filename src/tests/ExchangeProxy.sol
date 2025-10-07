// SPDX-License-Identifier: MIT
pragma solidity >0.6.6;

import "../Exchange.sol";
import "../CosmosTypes.sol";
import "../ExchangeTypes.sol";

contract ExchangeProxy {
    address constant exchangeContract = 0x0000000000000000000000000000000000000065;
    IExchangeModule exchange = IExchangeModule(exchangeContract);

    /// @dev Creates a derivative limit order on behalf of the specified sender. 
    /// It will revert with an error if this smart-contract doesn't have a grant 
    /// from the sender to perform this action on their behalf.
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

    /// @dev Creates multiple derivative limit orders on behalf of the specified sender.
    /// It will revert with an error if this smart-contract doesn't have a grant 
    /// from the sender to perform this action on their behalf.
    /// @param sender The address of the sender.
    /// @param orders Array of derivative orders to create.
    /// @return response The response from the batchCreateDerivativeLimitOrders call.
    function batchCreateDerivativeLimitOrders(
        address sender,
        IExchangeModule.DerivativeOrder[] calldata orders
    ) external returns (IExchangeModule.BatchCreateDerivativeLimitOrdersResponse memory response) {
        try exchange.batchCreateDerivativeLimitOrders(sender, orders) returns (IExchangeModule.BatchCreateDerivativeLimitOrdersResponse memory resp) {
            return resp;
        } catch {
            revert("error creating derivative limit orders in batch");
        }
    }

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