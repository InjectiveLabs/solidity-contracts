# IBC Transfer Precompile

## Overview

The IBC transfer precompile lets an EVM account or contract initiate an
ICS-20 transfer. Its Solidity interface is `IIBCModule`, defined in
[`src/IBC.sol`](../src/IBC.sol).

| Property | Value |
|----------|-------|
| Address | `0x0000000000000000000000000000000000000069` |
| Interface | `IIBCModule` |

## Interface

```solidity
interface IIBCModule {
    struct TimeoutHeight {
        uint64 revisionNumber;
        uint64 revisionHeight;
    }

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
```

The canonical ABI signature is:

```text
transfer(string,string,address,uint256,(uint64,uint64),uint64,string)
```

## Transfer semantics

- The source port is implicitly `transfer`.
- The IBC sender is the Injective Bech32 address derived from `msg.sender`.
  Callers cannot provide a different sender.
- `receiver` is the address understood by the counterparty chain. Its format is
  not restricted to an Injective or EVM address.
- `token` must resolve to a supported MTS bank denomination. An unknown token
  causes the call to revert.
- `amount` uses the token's smallest denomination and must be positive.
- No ERC-20 `approve` call is required. The precompile acts on the caller's
  native bank-backed MTS balance.
- Escrow or burn, packet creation, and packet commitment happen synchronously.
  The caller's balance reflects the transfer when the call returns.
- If the EVM execution containing the call later reverts, the balance change,
  packet commitment, sequence update, and associated events must also be
  reverted.
- If the packet later fails or times out, normal ICS-20 acknowledgement and
  timeout handling returns the funds to the sender.
- A successful call returns the outbound packet sequence number.

## Timeouts

`timeoutHeight` is evaluated using the counterparty chain's IBC client height:

- `revisionNumber` identifies the counterparty chain revision.
- `revisionHeight` is the block height within that revision.
- `{ revisionNumber: 0, revisionHeight: 0 }` disables the height timeout.

`timeoutTimestamp` is an absolute Unix timestamp in nanoseconds. A value of
zero disables the timestamp timeout. Callers should query current counterparty
chain state and add an appropriate safety margin. The underlying IBC
implementation validates the resulting timeout configuration.

## Receiver and memo limits

The precompile should apply the limits enforced by the underlying ibc-go
version. At the time this interface was specified, those limits are:

- Receiver: 2,048 bytes.
- Memo: 32,768 bytes.

No smaller precompile-specific limits should be imposed.

## Failure behavior

The call reverts without partial native or EVM state changes when, for example:

- The token cannot be resolved to an MTS denomination.
- The channel or timeout is invalid.
- The receiver or memo fails ICS-20 validation.
- The amount is zero or exceeds the caller's spendable balance.
- IBC sending is disabled for the token or channel.
- Packet creation, escrow, burn, or commitment fails.
