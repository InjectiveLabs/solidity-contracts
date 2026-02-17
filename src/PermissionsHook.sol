// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Cosmos} from "./CosmosTypes.sol";

interface IPermissionsHook {
    function isTransferRestricted(
        address from,
        address to,
        Cosmos.Coin calldata amount
    ) external view returns (bool);
}

/// @title PermissionsHook
/// @notice Base implementation of the permissions hook contract interface
/// @dev This contract provides a standard implementation that can be extended
///      to implement custom permission logic for token transfers
abstract contract PermissionsHook is IPermissionsHook {
    /// @notice Checks whether a transfer is restricted.
    /// @param from The address sending the tokens
    /// @param to The address receiving the tokens
    /// @param amount The amount being transferred (including denom)
    function isTransferRestricted(
        address from,
        address to,
        Cosmos.Coin calldata amount
    ) external view virtual returns (bool) {
        /// @dev Default implementation allows all transfers
        /// @dev Override this function in concrete implementations to add restrictions

        return false;
    }
}
