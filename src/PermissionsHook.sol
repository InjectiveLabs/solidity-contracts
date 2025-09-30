// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Cosmos} from "./CosmosTypes.sol";

interface IPermissionsHook {
    // check receive restrictions    
    function check_restrictions(
        address from,
        address to,
        Cosmos.Coin calldata amount
    ) external view;
}

/// @title PermissionsHook
/// @notice Base implementation of the permissions hook contract interface
/// @dev This contract provides a standard implementation that can be extended
///      to implement custom permission logic for token transfers
abstract contract PermissionsHook is IPermissionsHook {
    
    /// @notice Checks whether a transfer is allowed based on custom restrictions
    /// @dev This function should revert if the transfer is not allowed.
    ///      Implementations should override this function to add custom logic.
    ///      Default implementation allows all transfers.
    /// @param from The address sending the tokens
    /// @param to The address receiving the tokens  
    /// @param amount The amount being transferred (including denom)
    function check_restrictions(
        address from,
        address to,
        Cosmos.Coin calldata amount
    ) external view virtual {
        // Default implementation allows all transfers
        // Override this function in concrete implementations to add restrictions
    }
    
    /// @notice Internal function to revert with a custom restriction message
    /// @param reason The reason for the restriction
    function _revertWithRestriction(string memory reason) internal pure {
        revert(string(abi.encodePacked("Transfer restricted: ", reason)));
    }
    
    /// @notice Internal function to check if an address is the zero address
    /// @param addr The address to check
    /// @return true if the address is zero, false otherwise
    function _isZeroAddress(address addr) internal pure returns (bool) {
        return addr == address(0);
    }
}

/// @title RestrictAllPermissionsHook
/// @notice Concrete implementation that blocks ALL transfers
/// @dev This is a concrete contract that can be deployed for testing
contract RestrictAllPermissionsHook is PermissionsHook {
    
    /// @notice Implementation that denies all transfers
    /// @param from The address sending the tokens
    /// @param to The address receiving the tokens
    /// @param amount The amount being transferred
    function check_restrictions(
        address from,
        address to,
        Cosmos.Coin calldata amount
    ) external pure override {
        _revertWithRestriction("all operations are restricted");
    }
}

/// @title RestrictSpecificAddressHook
/// @notice Concrete implementation that blocks transfers for a specific address
/// @dev This contract blocks transfers involving 0x963EBDf2e1f8DB8707D05FC75bfeFFBa1B5BaC17
contract RestrictSpecificAddressHook is PermissionsHook {
    
    /// @notice Implementation that restricts specific address
    /// @param from The address sending the tokens
    /// @param to The address receiving the tokens
    /// @param amount The amount being transferred
    function check_restrictions(
        address from,
        address to,
        Cosmos.Coin calldata amount
    ) external pure override {
        // Restricted address that should be blocked from all transfers
        address restrictedAddress = 0x963EBDf2e1f8DB8707D05FC75bfeFFBa1B5BaC17;
        
        // Block transfers from the restricted address
        if (from == restrictedAddress) {
            _revertWithRestriction("Address 0x963EBDf2e1f8DB8707D05FC75bfeFFBa1B5BaC17 is restricted from sending");
        }
        
        // Block transfers to the restricted address  
        if (to == restrictedAddress) {
            _revertWithRestriction("Address 0x963EBDf2e1f8DB8707D05FC75bfeFFBa1B5BaC17 is restricted from receiving");
        }
        
        // All other transfers are allowed
    }
}