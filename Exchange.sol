// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IExchangeModule {
   function deposit(
      string memory subaccountID,
      string memory denom,
      uint256 amount
   ) external returns (bool);

   function createDerivativeLimitOrder(
      string memory marketID,
      string memory subaccountID,
      string memory feeRecipient,
      uint256 price,
      uint256 quantity,
      string memory cid,
      string memory orderType, // "buy", "sell", "buyPostOnly", or "sellPostOnly"
      uint256 margin,
      uint256 triggerPrice
   ) external returns (bool);
}