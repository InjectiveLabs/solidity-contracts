// SPDX-License-Identifier: MIT
pragma solidity >0.6.6;
import {IExchangeModule} from "./Exchange.sol";

contract TestExchange {
    address constant exchangeContract = 0x0000000000000000000000000000000000000065;
    IExchangeModule exchange = IExchangeModule(exchangeContract);

    function deposit(
        string memory subaccountID,
        string memory denom,
        uint256 amount
    ) external returns (bool) {
        return exchange.deposit(subaccountID, denom, amount);
    }
}