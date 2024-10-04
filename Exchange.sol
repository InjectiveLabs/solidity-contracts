// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IExchangeModule {

   /****************************************************************************
   * ACCOUNT QUERIES                                                           * 
   ****************************************************************************/

   /// @dev Queries a subaccount's deposits for a given denomination
   /// @param subaccountID The ID of the subaccount
   /// @param denom The coin denomination
   /// @return availableBalance The available balance of the deposit
   /// @return totalBalance The total balance of the deposit
   function subaccountDeposit (
      string calldata subaccountID,
      string calldata denom
   ) external view returns (uint256 availableBalance, uint256 totalBalance);

   /// @dev Queries all the deposits of a subaccount
   /// @param subaccountID The ID of the subaccount if trader and subaccountNonce are empty
   /// @param trader The address of the subaccount owner
   /// @param subaccountNonce The nonce of the subaccount
   /// @return deposits The array of deposits
   function subaccountDeposits(
      string calldata subaccountID,
      string calldata trader,
      uint32 subaccountNonce
   ) external view returns (subaccountDepositData[] calldata deposits);

   /// @dev subaccountDepositData contains the information about a deposit.
   struct subaccountDepositData {
      string denom;
      uint256 availableBalance;
      uint256 totalBalance;
   }

   /// @dev Queries all the derivative positions of a subaccount
   /// @param subaccountID The ID of the subaccount
   /// @return positions The array of positions
   function subaccountPositions(
      string calldata subaccountID
   ) external view returns (derivativePosition[] calldata positions);

   /// @dev derivativePosition records the conditions under which the trader has
   /// entered into the a derivative contract.
   /// note derivative orders represent intent, while positions represent 
   /// possession.
   struct derivativePosition {
      string subaccountID;
      string marketID;
      bool isLong;
      uint256 quantity;
      uint256 entryPrice;
      uint256 margin;
      uint256 cumulativeFundingEntry;
   }

   /****************************************************************************
   * ACCOUNT TRANSACTIONS                                                      * 
   ****************************************************************************/
   
   /// @dev Transfers coins from the sender's bank balance into the subaccount's
   /// exchange deposit. This will increase both the AvailableBalance and the
   /// TotalBalance of the subaccount's deposit by the provided amount.
   /// @param sender The address of the sender, where the funds will come from
   /// @param subaccountID (optional) The ID of the subaccount to deposit funds
   /// into. If empty, the coins will be deposited into the sender's default 
   /// subaccount
   /// @param denom The denomination of the coin to deposit
   /// @param amount The amount of coins to deposit
   /// @return success Whether the transaction was successful or not
   function deposit(
      address sender,
      string calldata subaccountID,
      string calldata denom,
      uint256 amount
   ) external returns (bool success);

   /// @dev Withdraws from a subaccount's deposit to the sender's bank balance.
   /// This will decrement the subaccount's AvailableBalance and TotalBalance by
   /// the specified amount. Note that amount must be less than or equal to the
   /// deposit's AvailableBalance.
   /// @param sender The address of the sender, where coins will be sent to
   /// @param subaccountID The ID of the subaccount to withdraw funds from.
   /// Note the ownership of the subaccount by sender will be verified.
   /// @param denom The denomination of coins to withdraw
   /// @param amount The amount of coins to withdraw
   /// @return success Whether the transaction was successful or not
   function withdraw(
      address sender,
      string calldata subaccountID,
      string calldata denom,
      uint256 amount
   ) external returns (bool success);

   /// @dev Transfers funds between two subaccounts owned by the sender
   /// @param sender The address of the sender
   /// @param sourceSubaccountID The ID of the originating subaccount
   /// @param destinationSubaccountID The ID of the destination subaccount
   /// @param denom The denomination of coins to transfer
   /// @param amount The amount of coins to transfer
   /// @return success Whether the transaction was a success or not
   function subaccountTransfer(
      address sender,
      string calldata sourceSubaccountID,
      string calldata destinationSubaccountID,
      string calldata denom,
      uint256 amount
   ) external returns (bool success);

   /// @dev Transfers funds from one of the sender's subaccounts to an external
   /// subaccount, not necessarily owned by the sender
   /// @param sender The address of the sender
   /// @param sourceSubaccountID The ID of the originating subaccount
   /// @param destinationSubaccountID The ID of the destination subaccount
   /// @param denom The denomination of coins to transfer
   /// @param amount The amount of coins to transfer
   /// @return success Whether the transaction was a success or not
   function externalTransfer(
      address sender,
      string calldata sourceSubaccountID,
      string calldata destinationSubaccountID,
      string calldata denom,
      uint256 amount
   ) external returns (bool success);

   /// @dev allows for the atomic cancellation and creation of spot and derivative 
   /// limit orders, along with a new order cancellation mode. Upon execution, 
   /// order cancellations (if any) occur first, followed by order creations 
   // (if any).
   /// @param sender The address of the sender
   /// @param request cf. batchUpdateOrdersRequest
   /// @return response cf. batchUpdateOrdersResponse
   function batchUpdateOrders(
      address sender,
      batchUpdateOrdersRequest calldata request
   ) external returns (batchUpdateOrdersResponse calldata response);

   /// @dev batchUpdateOrdersRequest encapsulates the parameters of batchUpdateOrders
   struct batchUpdateOrdersRequest {
      /// the sender's subaccount ID
      string subaccountID; 
      /// the list of spot market IDs for which the sender wants to cancel all open orders
      string[] spotMarketIDsToCancelAll; 
      /// the specific spot orders the sender wants to cancel
      orderData[] spotOrdersToCancel;
      /// the spot orders the sender wants to create
      spotOrder[] spotOrdersToCreate;
      /// the list of derivative market IDs for which the sender wants to cancel all open orders
      string[] derivativeMarketIDsToCancelAll;
      /// the specific derivative orders the sender wants to cancel
      orderData[] derivativeOrdersToCancel;
      /// the derivative orders the sender wants to create
      derivativeOrder[] derivativeOrdersToCreate;  
   }

   /// @dev batchUpdateOrdersResponse encapsulates the return values of batchUpdateOrders
   struct batchUpdateOrdersResponse {
      /// reflects the success of spot order cancellations
      bool[] spotCancelSuccess;
      /// hashes of created spot orders
      string[] spotOrderHashes;
      /// cids of created spot orders
      string[] createdSpotOrdersCids;
      /// cids of failed spot orders
      string[] failedSpotOrdersCids;
      /// reflects the success of derivative order cancellations
      bool[] derivativeCancelSuccess;
      /// hashes of created derivative orders
      string[] derivativeOrderHashes;
      /// cids of created derivative orders
      string[] createdDerivativeOrdersCids;
      /// cids of failed derivative orders
      string[] failedDerivativeOrdersCids;
   }

   /****************************************************************************
   * DERIVATIVE MARKETS QUERIES                                                * 
   ****************************************************************************/
   
   /// @dev retrieves a trader's derivative orders by market ID, subaccount ID, 
   /// and order hashes
   /// @param request cf. derivativeOrdersRequest
   /// @return orders the trader's derivative orders
   function derivativeOrdersByHashes(
      derivativeOrdersRequest calldata request
   ) external returns (trimmedDerivativeLimitOrder[] calldata orders);

   /// @dev encapsulates the parameters for derivativeOrdersByHashes
   struct derivativeOrdersRequest { 
      /// the ID of the market in which to look
      string marketID;
      /// the ID of the subaccount that created the orders
      string subaccountID;
      /// the hashes of orders to look for
      string[] orderHashes;
   }

   /// @dev trimmed representation of a derivative limit order
   struct trimmedDerivativeLimitOrder {
      uint256 price;
      uint256 quantity;
      uint256 margin;
      /// the amount of the quantity remaining fillable
      uint256 fillable;
      bool isBuy;
      string orderHash;
      string cid;
   }

   /****************************************************************************
   * DERIVATIVE MARKETS TRANSACTIONS                                           * 
   ****************************************************************************/
   
   /// @dev encapsulates fields required to create a derivative order (market or limit)
   struct derivativeOrder {
      /// the unique ID of the market
      string marketID;
      /// subaccount that placed the order
      string subaccountID;
      /// address that will receive fees for the order
      string feeRecipient;
      /// price of the order
      uint256 price;
      /// quantity of the order
      uint256 quantity;
      /// order identifier
      string cid;
      /// order type ("buy", "sell", "buyPostOnly", or "sellPostOnly")
      string orderType; 
      /// the margin used by the limit order
      uint256 margin;
      /// the trigger price used by stop/take orders
      uint256 triggerPrice; 
   }

   /// @dev encapsulates the return values of createDerivativeLimitOrder
   struct createDerivativeLimitOrderResponse {
      string orderHash;
      string cid;
   }

   /// @dev encapsulates the return values of batchCreateDerivativeLimitOrders
  struct batchCreateDerivativeLimitOrdersResponse {
      // hashes of created derivative limit orders
      string[] orderHashes;
      // cids of created orders
      string[] createdOrdersCids;
      // cids of failed orders
      string[] failedOrdersCids;
   }

   /// @dev encapsulates the return values of createDerivativeMarketOrderResponse
   struct createDerivativeMarketOrderResponse {
      string orderHash;
      string cid;
      uint256 quantity;
      uint256 price;
      uint256 fee;
      uint256 payout;
      uint256 deltaExecutionQuantity;
      uint256 deltaExecutionMargin;
      uint256 deltaExecutionPrice;
      bool deltaIsLong;
   }

   /// @dev encapsulates data used to identify an order to cancel 
   struct orderData {
      string marketID;
      string subaccountID;
      string orderHash;
      int32 orderMask;
      string cid;
   }

   /// @dev orderMask values
   ///
   ///      OrderMask_UNUSED        OrderMask = 0
	///      OrderMask_ANY           OrderMask = 1
	///      OrderMask_REGULAR       OrderMask = 2
	///      OrderMask_CONDITIONAL   OrderMask = 4
	///      OrderMask_BUY_OR_HIGHER OrderMask = 8
	///      OrderMask_SELL_OR_LOWER OrderMask = 16
	///      OrderMask_MARKET        OrderMask = 32
	///      OrderMask_LIMIT         OrderMask = 64

   /// @dev create a derivative limit order
   /// @param sender The address of the sender
   /// @param order The derivative order to create (cf. derivativeOrder)
   /// @return response cf createDerivativeLimitOrderResponse
   function createDerivativeLimitOrder(
      address sender,
      derivativeOrder calldata order
   ) external returns (createDerivativeLimitOrderResponse calldata response);

   /// @dev create a batch of derivative limit orders
   /// @param sender The address of the sender
   /// @param orders The orders to create
   /// @return response cf. batchCreateDerivativeLimitOrdersResponse
   function batchCreateDerivativeLimitOrders(
      address sender,
      derivativeOrder[] calldata orders
   ) external returns (batchCreateDerivativeLimitOrdersResponse calldata response);

   /// @dev create a derivative market order
   /// @param sender The address of the sender
   /// @param order The order to create
   /// @return response cf. batchCreateDerivativeMarketOrderResponse
   function createDerivativeMarketOrder(
      address sender,
      derivativeOrder calldata order
   ) external returns (createDerivativeMarketOrderResponse calldata response);

   /// @dev cancel a derivative order
   /// @param marketID The market the order is in
   /// @param subaccountID The subaccount that placed the order
   /// @param orderHash The order hash
   /// @param orderMask The order mask (use default 0 if you don't know what this is)
   /// @param cid The identifier of the order
   /// @return success Whether the order was successfully cancelled
   function cancelDerivativeOrder(
      address sender,
      string calldata marketID,
      string calldata subaccountID,
      string calldata orderHash,
      int32 orderMask,
      string calldata cid
   ) external returns (bool success);

   /// @dev cancel a batch of derivative orders
   /// @param sender The address of the sender
   /// @param data The data of the orders to cancel
   /// @return success Whether each cancellation succeeded
   function batchCancelDerivativeOrders(
      address sender,
      orderData[] calldata data
   ) external returns (bool[] calldata success);

   /// @dev increase the margin of a position
   /// @param sender The address of the sender
   /// @param sourceSubaccountID The subaccount to send balance from
   /// @param destinationSubaccountID The subaccount that owns the position
   /// @param marketID The market where position is in
   /// @param amount The amount by which to increase the position margin
   /// @return success Whether the operation succeeded or not
   function increasePositionMargin(
      address sender,
      string calldata sourceSubaccountID,
      string calldata destinationSubaccountID,
      string calldata marketID,
      uint256 amount
   ) external returns (bool success);

   /// @dev defines a request to decrease the margin of a position
   /// @param sender The address of the sender
   /// @param sourceSubaccountID The subaccount that owns the position
   /// @param destinationSubaccountID The subaccount to send balance to
   /// @param marketID The market where position is in
   /// @param amount The amount by which to decrease the position margin
   /// @return success Whether the operation succeeded or not
   function decreasePositionMargin(
      address sender,
      string calldata sourceSubaccountID,
      string calldata destinationSubaccountID,
      string calldata marketID,
      uint256 amount
   ) external returns (bool success);

   /****************************************************************************
   * SPOT MARKETS QUERIES                                                      * 
   ****************************************************************************/
 
   /// @dev retrieves a trader's spot orders by market ID, subaccount ID, 
   /// and order hashes
   /// @param request cf. spotOrdersRequest
   /// @return orders the trader's spot orders
   function spotOrdersByHashes(
      spotOrdersRequest calldata request
   ) external returns (trimmedSpotLimitOrder[] calldata orders);

   /// @dev encapsulates the parameters for spotOrdersByHashes
   struct spotOrdersRequest {
      /// the ID of the market in which to look
      string marketID;
      /// the ID of the subaccount that placed the orders
      string subaccountID;
      /// the hashes of orders to look for
      string[] orderHashes;
   }

   /// @dev trimmed representation of a spot limit order
   struct trimmedSpotLimitOrder {
      uint256 price;
      uint256 quantity;
      /// the amount of the quantity remaining fillable
      uint256 fillable;
      bool isBuy;
      string orderHash;
      string cid;
   }

   /****************************************************************************
   * SPOT MARKETS TRANSACTIONS                                                 * 
   ****************************************************************************/

   /// @dev encapsulates fields required to create a spot order (market or limit)
   struct spotOrder {
      /// the unique ID of the market
      string marketID;
      /// subaccount that creates the order
      string subaccountID;
      /// address that will receive fees for the order
      string feeRecipient;
      /// price of the order
      uint256 price;
      /// quantity of the order
      uint256 quantity;
      /// order identifier
      string cid;
      /// order type ( "buy", "sell", "buyPostOnly", or "sellPostOnly")
      string orderType;
      /// the trigger price used by stop/take orders
      uint256 triggerPrice;
   }

   /// @dev encapsulates the return values of createSpotLimitOrder
   struct createSpotLimitOrderResponse {
      string orderHash;
      string cid;
   }

   /// @dev encapsulates the return values of batchCreateSpotLimitOrders
   struct batchCreateSpotLimitOrdersResponse {
      /// hashes of created spot orders
      string[] orderHashes;
      /// cids of created spot orders
      string[] createdOrdersCids;
      /// cids of failed spot orders
      string[] failedOrdersCids;
   }

   /// @dev encapsulates the return values of createSpotMarketOrder
   struct createSpotMarketOrderResponse {
      string orderHash;
      string cid;
      uint256 quantity;
      uint256 price;
      uint256 fee;
   }

   /// @dev create a spot limit order
   /// @param sender The address of the sender
   /// @param order The spot order to create (cf. spotOrder)
   /// @return response cf. createSpotLimitOrderResponse
   function createSpotLimitOrder(
      address sender,
      spotOrder calldata order
   ) external returns (createSpotLimitOrderResponse calldata response);

   /// @dev create a batch of spot limit orders
   /// @param sender The address of the sender
   /// @param orders The orders to create
   /// @return response cf. batchCreateSpotLimitOrdersResponse
   function batchCreateSpotLimitOrders(
      address sender,
      spotOrder[] calldata orders
   ) external returns (batchCreateSpotLimitOrdersResponse calldata response);

   /// @dev create a spot market order
   /// @param sender The address of the sender
   /// @param order The order to create
   /// @return response cf. batchCreateSpotMarketOrderResponse
   function createSpotMarketOrder(
      address sender,
      spotOrder calldata order
   ) external returns (createSpotMarketOrderResponse calldata response);

   /// @dev cancel a spot order
   /// @param marketID The market the order is in
   /// @param subaccountID The subaccount that created the order
   /// @param orderHash The order hash
   /// @param cid The identifier of the order
   /// @return success Whether the order was successfully cancelled
   function cancelSpotOrder(
      address sender,
      string calldata marketID,
      string calldata subaccountID,
      string calldata orderHash,
      string calldata cid
   ) external returns (bool success);

   /// @dev cancel a batch of spot orders
   /// @param sender The address of the sender
   /// @param data The data of the orders to cancel
   /// @return success Whether each cancellation succeeded
   function batchCancelSpotOrders(
      address sender,
      orderData[] calldata data
   ) external returns (bool[] calldata success);

  



 

   
}