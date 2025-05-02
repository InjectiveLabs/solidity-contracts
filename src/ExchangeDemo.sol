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
}