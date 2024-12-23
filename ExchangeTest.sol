// SPDX-License-Identifier: MIT
pragma solidity >0.6.6;

import  "./Exchange.sol";

contract ExchangeTest {
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


    /***************************************************************************
     * calling the precompile via delegateCall
    ****************************************************************************/

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

    /***************************************************************************
     * calling the precompile via authz
    ****************************************************************************/

    /// @dev Approves a message type, so that this contract can submit it on 
    /// behalf of the origin. 
    /// @param msgType The type of the message to approve.
    /// @param spendLimit The spend limit for the message type.
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

       // A simple counter to be incremented
    uint256 public counter;

    //  depositTest1 is used ot test that our evm module is not affected by the
    // bug outlined here:
    // https://github.com/InjectiveLabs/injective-core/issues/1000
    function depositTest1(
        string memory subaccountID,
        string memory denom,
        uint256 amount
    ) external returns (bool) {
        counter++;
        bool success = exchange.deposit(msg.sender, subaccountID, denom, amount);
        counter--;
        return success;
    }

    // depositTest2 is used to test that our evm module is not affected by the
    // bug outlined here:
    // https://forum.cosmos.network/t/critical-evm-precompiled-contract-bug-allowing-unlimited-token-mint/14060
    function depositTest2(
        string memory subaccountID,
        string memory denom,
        uint256 amount
    ) external returns (bool) {
        try this.depositAndRevert(subaccountID, denom, amount) returns (bool success) {
            return success;
        } catch {
        }
        return false;
    }

    function depositAndRevert(
        string memory subaccountID,
        string memory denom,
        uint256 amount
    ) external returns (bool) {
        exchange.deposit(msg.sender, subaccountID, denom, amount);
        revert("testing");
    }
}