// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Injective IBC transfer precompile
/// @notice Initiates ICS-20 transfers from EVM accounts and contracts.
/// @dev Deployed at 0x0000000000000000000000000000000000000069.
interface IIBCModule {
    /// @notice Identifies an IBC client revision and a block height within it.
    /// @dev Set both fields to zero to disable the height-based timeout.
    struct TimeoutHeight {
        uint64 revisionNumber;
        uint64 revisionHeight;
    }

    /// @notice Transfers an MTS token over an ICS-20 channel.
    /// @dev The source port is implicitly `transfer`. The IBC sender is the
    ///      Injective Bech32 address derived from `msg.sender`.
    ///
    ///      The token must resolve to a supported MTS bank denomination. The
    ///      amount is debited synchronously and is escrowed or burned according
    ///      to ICS-20 semantics. No ERC-20 approval is required.
    ///
    ///      A zero timeout height disables the height-based timeout. A zero
    ///      timeout timestamp disables the timestamp-based timeout. The call
    ///      must supply a timeout accepted by the underlying IBC implementation.
    ///
    /// @param sourceChannel Source-side ICS-20 channel identifier.
    /// @param receiver Receiver address on the counterparty chain.
    /// @param token EVM address of the MTS token to transfer.
    /// @param amount Amount in the token's smallest denomination.
    /// @param timeoutHeight Counterparty-chain IBC timeout height.
    /// @param timeoutTimestamp Absolute Unix timeout timestamp in nanoseconds.
    /// @param memo ICS-20 packet memo.
    /// @return sequence Sequence number assigned to the outbound IBC packet.
    function transfer(
        string calldata sourceChannel,
        string calldata receiver,
        address token,
        uint256 amount,
        TimeoutHeight calldata timeoutHeight,
        uint64 timeoutTimestamp,
        string calldata memo
    ) external returns (uint64 sequence);
}
