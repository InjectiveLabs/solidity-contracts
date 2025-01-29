// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Cosmos} from "./CosmosTypes.sol";
import {StakingTypes} from "./StakingTypes.sol";

interface IStakingModule {
    /***************************************************************************
    * AUTHZ                                                                    * 
    ***************************************************************************/
   
   /// @dev Approves a list of Cosmos messages.
   /// @param grantee The account address which will have an authorization to spend the origin funds.
   /// @param methods The message type URLs of the methods to approve.
   /// @param spendLimit The spend limit for the methods.
   /// @return approved Boolean value to indicate if the approval was successful.
   function approve(
      address grantee,
      StakingTypes.MsgType[] calldata methods,
      Cosmos.Coin calldata spendLimit
   ) external returns (bool approved);

   /// @dev Revokes a list of Cosmos messages.
   /// @param grantee The contract address which will have its allowances revoked.
   /// @param methods The message type URLs of the methods to revoke.
   /// @return revoked Boolean value to indicate if the revocation was successful.
   function revoke(
      address grantee,
      StakingTypes.MsgType[] calldata methods
   ) external returns (bool revoked);

   /// @dev Checks if there is a valid grant from granter to grantee for specified
   /// message type
   /// @param grantee The contract address which has the Authorization.
   /// @param granter The account address that grants an Authorization.
   /// @param method The message type URL of the methods for which the approval should be queried.
   /// @return allowed Boolean value to indicatie if the grant exists and is not expired
   function allowance(
      address grantee,
      address granter,
      StakingTypes.MsgType method
   ) external view returns (bool allowed);

    
    /***************************************************************************
    * STAKING                                                                 * 
    ***************************************************************************/

    /// @dev Defines a method for performing a delegation of coins from a delegator to a validator.
    /// @param delegatorAddress The address of the delegator
    /// @param validatorAddress The address of the validator
    /// @param amount The amount of the bond denomination to be delegated to the validator.
    /// This amount should use the bond denomination precision stored in the bank metadata.
    /// @return success Whether or not the delegate was successful
    function delegate(
        address delegatorAddress,
        string memory validatorAddress,
        uint256 amount
    ) external returns (bool success);

    /// @dev Defines a method for performing an undelegation from a delegate and a validator.
    /// @param delegatorAddress The address of the delegator
    /// @param validatorAddress The address of the validator
    /// @param amount The amount of the bond denomination to be undelegated from the validator.
    /// This amount should use the bond denomination precision stored in the bank metadata.
    /// @return success Whether or not the undelegate was successful
    function undelegate(
        address delegatorAddress,
        string memory validatorAddress,
        uint256 amount
    ) external returns (bool success);

    /// @dev Defines a method for performing a redelegation
    /// of coins from a delegator and source validator to a destination validator.
    /// @param delegatorAddress The address of the delegator
    /// @param validatorSrcAddress The validator from which the redelegation is initiated
    /// @param validatorDstAddress The validator to which the redelegation is destined
    /// @param amount The amount of the bond denomination to be redelegated to the validator
    /// This amount should use the bond denomination precision stored in the bank metadata.
    /// @return success Whether or not the redelegate was successful
    function redelegate(
        address delegatorAddress,
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
    /// @param delegatorAddress The address of the delegator
    /// @param validatorAddress The address of the validator
    /// @return amount The amount of Coin withdrawn
    function withdrawDelegatorRewards(
        address delegatorAddress,
        string memory validatorAddress
    ) external returns (Cosmos.Coin[] calldata amount);

}
