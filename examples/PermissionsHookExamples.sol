// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Cosmos} from "../src/CosmosTypes.sol";
import {PermissionsHook} from "../src/PermissionsHook.sol";

/// @title RestrictAllTransfersHook
/// @notice Concrete implementation that blocks ALL transfers
/// @dev This is a concrete contract that can be deployed for testing
contract RestrictAllTransfersHook is PermissionsHook {
    /// @notice Implementation that denies all transfers
    /// @param from The address sending the tokens
    /// @param to The address receiving the tokens
    /// @param amount The amount being transferred
    function isTransferRestricted(
        address from,
        address to,
        Cosmos.Coin calldata amount
    ) external pure override returns (bool) {
        return true;
    }
}

/// @title RestrictSpecificAddressTransferHook
/// @notice Concrete implementation that blocks transfers for a specific address
/// @dev This contract blocks transfers involving 0x963EBDf2e1f8DB8707D05FC75bfeFFBa1B5BaC17
contract RestrictSpecificAddressTransferHook is PermissionsHook {
    address constant restrictedAddress =
        0x963EBDf2e1f8DB8707D05FC75bfeFFBa1B5BaC17;

    /// @notice Implementation that restricts specific address
    /// @param from The address sending the tokens
    /// @param to The address receiving the tokens
    /// @param amount The amount being transferred
    function isTransferRestricted(
        address from,
        address to,
        Cosmos.Coin calldata amount
    ) external pure override returns (bool) {
        if (from == restrictedAddress || to == restrictedAddress) {
            return true;
        }

        /// @dev All other transfers are allowed
        return false;
    }
}
