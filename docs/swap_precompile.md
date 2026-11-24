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
- Calls carrying `msg.value` revert. All three swap methods
  (`swapExactInputV1`, `swapExactInputV2`, `swapExactOutputV1`) revert inside
  a static call with `the method is not readonly`.
- The swap matches the book as-is, including resting orders of the caller's
  own default subaccount, and pays the taker fee on those fills. Keep this in
  mind in a contract that also places orders through the exchange precompile.
- Any failure reverts the whole call, and a revert in the calling frame
  rolls the swap back. Multi-hop routes compose by chaining calls.

### Fees

A swap is an atomic market order, so it pays the market's taker fee ×
`spot_atomic_market_order_fee_multiplier`. The caller is the order's fee
recipient, so the relayer share (`relayer_fee_share_rate`) comes back to it.
With default params:

| | Rate |
|---|---|
| Taker fee | 0.1% |
| × atomic multiplier 2.5 | 0.25% gross |
| − 40% relayer share returned | **0.15% net** |

A caller with a fee-discount tier pays less at execution. The fee is charged
in the quote token: a buy's `amountInSpent` covers the trade value plus the
fee, and a sell's `amountOut` is the trade value minus the fee. In the demo, a
49.92 USDC buy pays 0.07488 USDC (0.15%).

## Partial fills

An exact-input swap whose `amountIn` exceeds what the book can absorb fills
what it can and leaves the rest with the caller. It reverts only if the
output is below `minOut`.

- `swapExactInputV1` does not report this. It returns the partial
  `amountOut`, and `quoteExactInputV1` returns the same partial output, so a
  `minOut` taken from that quote does not catch it.
- `swapExactInputV2` and `quoteExactInputV2` also return `amountInSpent`. To
  reject a partial fill, compare it with `amountIn` in the calling contract
  and revert. Allow for the tick floor below.
- `swapExactOutputV1` never fills partially. It reverts if the book cannot
  deliver `amountOut` within `maxAmountIn`.

### Tick floor

Fills are floored to the market's minimum quantity tick. Even a full fill can
leave less than one tick's worth of `amountIn` unspent. **`amountInSpent ==
amountIn` is therefore not a full-fill check.** A remainder below one tick's
worth of input is a full fill. That threshold is in `amountIn`'s units, so it
depends on the direction:

- **Sell** (input is the base token): one quantity tick, in base units.
- **Buy** (input is the quote token): one tick × the price of the first ask
  level the swap did not fully use × (1 + net fee), in quote units. A
  quantity tick alone is the wrong unit here and can't be compared with the
  remainder.

For example, on the demo's INJ/USDC market (0.001 INJ tick, 18/6 decimals,
0.15% net fee), one tick at an ask of 10.0 costs
0.001 × 10.0 × 1.0015 = 0.010015 USDC (10,015 raw). A 50 USDC buy that leaves
5,120 raw unspent filled completely; the over-depth buy that leaves
364,717,380 raw unspent did not, even though that is far below one INJ tick
(1e15 raw).

When the price of that level isn't known on-chain, bound it from above: one
tick at the limit price (or the deepest ask the swap may reach) is a safe
threshold that can only flag a full fill as partial, never the reverse.
Alternatively, call `quoteExactInputV2` first and compare against its
`amountInSpent`.

`swapExactOutputV1` can deliver more than `amountOut` for two reasons: fills
happen in whole ticks, and its input is sized at the undiscounted fee, so a
caller with a fee-discount tier gets the discount back as extra output.

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
// `limitPrice` is quote per base, 1e18-scaled. Multiply before dividing so
// the result doesn't truncate when the decimals differ.

// Buy base with `amountIn` quote, paying at most `limitPrice`:
uint256 minOut = amountIn * 10**baseDecimals * 1e18 / (10**quoteDecimals * limitPrice);

// Sell `amountIn` base for quote, receiving at least `limitPrice`:
uint256 minOut = amountIn * limitPrice * 10**quoteDecimals / (10**baseDecimals * 1e18);
```

The output is net of the fee (see [Fees](#fees)), so a `minOut` derived this
way is a fee-inclusive limit: at a 0.15% net fee, a buy's average book price
can be at most about `limitPrice / 1.0015`.

Quotes use the undiscounted fee and walk the aggregated book, which
includes paused or frozen makers that live matching skips. A quote can
therefore overstate the fill slightly, while `minOut` or `maxAmountIn` is
always enforced on execution.

### Setting `maxAmountIn`

`swapExactOutputV1` sizes its input with `quoteExactOutputV1` and reverts if
that quote is above `maxAmountIn`. The quote rounds up and can include one
unit of headroom above what the swap actually spends: in the demo the quote
is 20,030,001 and the swap spends 20,030,000. Set `maxAmountIn` to at least
the quote, never to the expected spend, or the call reverts with
`required input 20030001 is above maximum 20030000`.

## Gas

Each call pays an upfront cost: the calldata length × the KV store's
`WriteCostPerByte`, plus a floor of 60,000 for quotes, 200,000 for
exact-input swaps and 260,000 for `swapExactOutputV1`.

The native work the call performs is measured and counts toward the floor,
so only work beyond the floor costs extra. Walking a deep book costs more.

If the forwarded gas cannot cover the work, the call fails with out-of-gas
and burns all the gas forwarded to it. A Solidity `try`/`catch` around the
call still sees the failure, as a revert with no reason, but forward enough
gas rather than relying on it.

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
| `the method is not readonly` | A swap method was called inside a static call |
| `exchange is in post-only mode` | The exchange is in post-only mode, e.g. for a while after chain downtime or on a fresh genesis |
| `swap amount must be positive` | `amountIn` or `amountOut` is zero |
| `maxIn must be positive` | `swapExactOutputV1` with `maxAmountIn` of zero |
| `is a blocked address` | `recipient` is a module or other blocked address |
| `was not delivered to the caller's bank balance` | The output token's transfer restrictions block the caller or recipient, e.g. a USDC blacklist |
| `quantity tick … is finer than one chain unit` | The market's quantity tick is below one base unit; it can't be swapped |
| `has pending scheduled settlement exposure` | The caller holds a derivative position in a market waiting to be settled; swaps are frozen until it settles |

## Market allowlist

`swap_params` holds an `enabled` flag and the `allowed_markets` list. It is
updated with `MsgUpdateSwapParams`, sent by the governance authority or by an
address in the exchange `exchange_admins` param. The message replaces the
whole group, so list every market that should stay allowlisted. The
[swap demo](../demos/swap/demo.sh) shows the full flow.
