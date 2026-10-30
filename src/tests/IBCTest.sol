// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IIBCModule} from "../IBC.sol";

/// @notice Integration helper for exercising the IBC precompile from a contract.
contract IBCTest {
    error ForcedRevert();

    IIBCModule public constant IBC = IIBCModule(0x0000000000000000000000000000000000000069);

    function transfer(
        string calldata sourceChannel,
        string calldata receiver,
        address token,
        uint256 amount,
        IIBCModule.TimeoutHeight calldata timeoutHeight,
        uint64 timeoutTimestamp,
        string calldata memo
    ) external returns (uint64 sequence) {
        return IBC.transfer(sourceChannel, receiver, token, amount, timeoutHeight, timeoutTimestamp, memo);
    }

    /// @notice Used to verify that an enclosing EVM revert rolls back the IBC send.
    function transferThenRevert(
        string calldata sourceChannel,
        string calldata receiver,
        address token,
        uint256 amount,
        IIBCModule.TimeoutHeight calldata timeoutHeight,
        uint64 timeoutTimestamp,
        string calldata memo
    ) external {
        IBC.transfer(sourceChannel, receiver, token, amount, timeoutHeight, timeoutTimestamp, memo);
        revert ForcedRevert();
    }
}
