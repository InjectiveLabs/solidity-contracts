// SPDX-License-Identifier: MIT
pragma solidity >0.6.6;

import  "./Exchange.sol";

contract ExchangeTest {
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
}