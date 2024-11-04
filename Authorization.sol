// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.8.17;

/// @title Authorization Interface
/// @dev The interface through which solidity contracts will interact with smart contract approvals.
interface IAuthorization {
    /// @dev Approves a list of Cosmos messages.
    /// @param grantee The contract address which will have an authorization to spend the origin funds.
    /// @param methods The message type URLs of the methods to approve.
    /// @return approved Boolean value to indicate if the approval was successful.
    function approve(
        address grantee,
        string[] calldata methods
    ) external returns (bool approved);

    /// @dev Revokes a list of Cosmos messages.
    /// @param grantee The contract address which will have its allowances revoked.
    /// @param methods The message type URLs of the methods to revoke.
    /// @return revoked Boolean value to indicate if the revocation was successful.
    function revoke(
        address grantee,
        string[] calldata methods
    ) external returns (bool revoked);

    /// @dev Returns the remaining number of tokens that spender will be allowed to spend
    /// on behalf of the owner through IBC transfer methods or staking. This is zero by default.
    /// @param grantee The contract address which has the Authorization.
    /// @param granter The account address that grants an Authorization.
    /// @param method The message type URL of the methods for which the approval should be queried.
    /// @return remaining The remaining number of tokens available to be spent.
    function allowance(
        address grantee,
        address granter,
        string calldata method
    ) external view returns (uint256 remaining);
}
