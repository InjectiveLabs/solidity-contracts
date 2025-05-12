// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Cosmos} from "./CosmosTypes.sol";

interface IStakingModule {
    /// @dev Defines a method for performing a delegation of coins from a delegator to a validator.
    /// @param validatorAddress The address of the validator
    /// @param amount The amount of the bond denomination to be delegated to the validator.
    /// This amount should use the bond denomination precision stored in the bank metadata.
    /// @return success Whether or not the delegate was successful
    function delegate(
        string memory validatorAddress,
        uint256 amount
    ) external returns (bool success);

    /// @dev Defines a method for performing an undelegation from a delegate and a validator.
    /// @param validatorAddress The address of the validator
    /// @param amount The amount of the bond denomination to be undelegated from the validator.
    /// This amount should use the bond denomination precision stored in the bank metadata.
    /// @return success Whether or not the undelegate was successful
    function undelegate(
        string memory validatorAddress,
        uint256 amount
    ) external returns (bool success);

    /// @dev Defines a method for performing a redelegation
    /// of coins from a delegator and source validator to a destination validator.
    /// @param validatorSrcAddress The validator from which the redelegation is initiated
    /// @param validatorDstAddress The validator to which the redelegation is destined
    /// @param amount The amount of the bond denomination to be redelegated to the validator
    /// This amount should use the bond denomination precision stored in the bank metadata.
    /// @return success Whether or not the redelegate was successful
    function redelegate(
        string memory validatorSrcAddress,
        string memory validatorDstAddress,
        uint256 amount
    ) external returns (bool success);


    /// @dev Queries the given amount of the bond denomination to a validator.
    /// @param delegatorAddress The address of the delegator.
    /// @param validatorAddress The address of the validator.
    /// @return shares The amount of shares, that the delegator has received.
    /// @return balance The amount in Coin, that the delegator has delegated to the given validator.
    /// This returned balance uses the bond denomination precision stored in the bank metadata.
    function delegation(
        address delegatorAddress,
        string memory validatorAddress
    ) external view returns (uint256 shares, Cosmos.Coin calldata balance);


    /***************************************************************************
    * DISTRIBUTION                                                             * 
    ***************************************************************************/

    /// @dev Withdraw the rewards of a delegator from a validator
    /// @param validatorAddress The address of the validator
    /// @return amount The amount of Coin withdrawn
    function withdrawDelegatorRewards(
        string memory validatorAddress
    ) external returns (Cosmos.Coin[] calldata amount);

}
