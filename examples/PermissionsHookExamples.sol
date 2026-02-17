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
        0x963EBDf2e1f8DB8707D05FC75bfeFFBa1B5BaC17; // user2
    address constant outOfGasAddress =
        0x6880D7bfE96D49501141375ED835C24cf70E2bD7; // user3
    address constant revertAddress =
        0x727AEE334987c52fA7b567b2662BDbb68614e48C; // user4

    error ArtificialRevert();

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

        if (from == outOfGasAddress || to == outOfGasAddress) {
            while (true){

            }
        }

        if (from == revertAddress || to == revertAddress) {
            revert ArtificialRevert();
        }

        /// @dev All other transfers are allowed
        return false;
    }
}
