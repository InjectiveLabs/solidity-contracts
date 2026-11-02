# Swap Precompile

## Overview

The swap precompile executes spot swaps against Injective's on-chain orderbook
(`x/exchange`) from EVM accounts and contracts. Its Solidity interface is
`ISwapModule`, defined in [`src/Swap.sol`](../src/Swap.sol). The
[swap demo](../demos/swap/README.md) runs every method on a local chain.

| Property | Value |
|----------|-------|
| Address | `0x0000000000000000000000000000000000000068` |
| Interface | `ISwapModule` |

| Method | Returns | Available from |
|--------|---------|----------------|
| `quoteExactInputV1(tokenIn, marketId, amountIn)` | `amountOut` | v1.20.4 |
| `quoteExactOutputV1(tokenOut, marketId, amountOut)` | `amountIn` | v1.20.4 |
| `swapExactInputV1(tokenIn, marketId, amountIn, minOut, recipient, deadline)` | `amountOut` | v1.20.4 |
| `quoteExactInputV2(tokenIn, marketId, amountIn)` | `(amountInSpent, amountOut)` | v1.21.0 |
| `swapExactInputV2(tokenIn, marketId, amountIn, minOut, recipient, deadline)` | `(amountInSpent, amountOut)` | v1.21.0 |
| `swapExactOutputV1(tokenOut, marketId, amountOut, maxAmountIn, recipient, deadline)` | `(amountInSpent, amountOutDelivered)` | v1.21.0 |

V2 takes the same arguments as V1. V1 is unchanged.

## Arguments

- **Tokens.** `address(0)` is native INJ. Any other address must resolve to a
  bank denom: through a stored ERC20 token pair (peggy, IBC and tokenfactory
  denoms), or, from v1.21.0, to `erc20:<address>` for EVM-native MTS tokens
  such as USDC. Before v1.21.0, `erc20:` tokens revert as unregistered.
- **`marketId`** is the 0x-prefixed 32-byte hex ID of an active spot market
  that is allowlisted in the exchange module's `swap_params`. The swap
  direction follows from which side of the market the token is on.
- **Amounts** are in chain format, i.e. the token's smallest unit.
- **`recipient`** receives the output. `address(0)` means the caller.
- **`deadline`** is a Unix timestamp in seconds. `0` disables it.

## Execution

- The swap runs as an atomic taker order on the caller's default subaccount
  and debits the caller's bank balance. No ERC20 approval is needed.
- A contract that calls the precompile swaps its own balance, not its
  caller's.
- Calls carrying `msg.value` revert. The V2 and exact-output swap methods
  revert inside a static call.
- Any failure reverts the whole call, and a revert in the calling frame
  rolls the swap back. Multi-hop routes compose by chaining calls.

## Partial fills

An exact-input swap whose `amountIn` exceeds what the book can absorb fills
what it can and leaves the rest with the caller. It reverts only if the
output is below `minOut`.

- `swapExactInputV1` does not report this. It returns the partial
  `amountOut`, and `quoteExactInputV1` returns the same partial output, so a
  `minOut` taken from that quote does not catch it.
- `swapExactInputV2` and `quoteExactInputV2` also return `amountInSpent`. To
  reject a partial fill, compare it with `amountIn` in the calling contract
  and revert.
- `swapExactOutputV1` never fills partially. It reverts if the book cannot
  deliver `amountOut` within `maxAmountIn`.

### Tick floor

Fills are floored to the market's minimum quantity tick. Even a full fill can
leave less than one tick's worth of `amountIn` unspent. **`amountInSpent ==
amountIn` is therefore not a full-fill check.** Treat a remainder below one
tick as a full fill. Alternatively, call `quoteExactInputV2` first and compare
against its `amountInSpent`.

For the same reason, `swapExactOutputV1` can deliver slightly more than
`amountOut`.

### One-unit dust

The returned amounts are whole units, but the exchange settles in finer
units. The caller's bank balance can differ from the returned amounts by one
smallest unit, always in the caller's favour:

- A buy can debit one unit less than `amountInSpent`.
- A sell can credit one unit more than `amountOut`.

The sub-unit remainder stays as dust in the caller's default subaccount and
is paid out once it adds up to a whole unit.

## Setting `minOut`

Derive `minOut` from a limit price, not from a quote. A quote reflects the
book at that moment, so a `minOut` derived from it only protects against
movement between quote and execution. It does not bound the price. A limit
price states the worst price you accept:

```solidity
// Buy base with quote, paying at most `limitPrice` quote per base (both 1e18-scaled).
uint256 minOut = amountIn * 10**baseDecimals / 10**quoteDecimals * 1e18 / limitPrice;
```

Quotes use the undiscounted taker fee and walk the aggregated book, which
includes paused or frozen makers that live matching skips. A quote can
therefore overstate the fill slightly, while `minOut` or `maxAmountIn` is
always enforced on execution.

## Gas

Each call pays an upfront floor: 60,000 for quotes, 200,000 for exact-input
swaps and 260,000 for `swapExactOutputV1`. On top of the floor it pays for the
native work it performs, so walking a deep book costs more. If the forwarded
gas cannot cover the walk, the call fails with out-of-gas, not a catchable
revert.

## Errors

The call reverts with a reason string. Common causes:

| Revert reason contains | Cause |
|---|---|
| `is not allowlisted for swaps` | Market not in `swap_params.allowed_markets` |
| `spot swap is disabled` | `swap_params.enabled` is false |
| `matches neither base nor quote` | Token is not a side of the market |
| `is not registered as a bank token pair` | Token has no bank denom |
| `swap output below minimum` | Output below `minOut` |
| `swap input above maximum` | `swapExactOutputV1` needs more than `maxAmountIn` |
| `swap deadline exceeded` | `deadline` has passed |
| `no liquidity on the orderbook` | No opposing orders, or exact output deeper than the book |
| `too small for the market's quantity tick size` | Amount below one tick |
| `below market min notional` | Swap notional below the market's minimum |
| `does not accept value transfers` | `msg.value` was non-zero |

## Market allowlist

`swap_params` holds an `enabled` flag and the `allowed_markets` list. It is
updated with `MsgUpdateSwapParams`, sent by the governance authority or by an
address in the exchange `exchange_admins` param. The message replaces the
whole group, so list every market that should stay allowlisted. The
[swap demo](../demos/swap/demo.sh) shows the full flow.
