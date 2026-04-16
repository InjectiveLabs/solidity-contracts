// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Cosmos} from "./CosmosTypes.sol";

interface IPermissionsPostHook {
    function postTransfer(
        address from,
        address to,
        Cosmos.Coin calldata amount
    ) external;
}

abstract contract PermissionsPostHook is IPermissionsPostHook {
    function postTransfer(
        address from,
        address to,
        Cosmos.Coin calldata amount
    ) external virtual {}
}
