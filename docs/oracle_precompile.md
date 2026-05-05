# Oracle Precompile

## Overview

The Oracle precompile exposes on-chain reference prices to native EVM contracts.
It is read-only and supports all active oracle types on the Injective chain.

| Property | Value |
|----------|-------|
| Address  | `0x0000000000000000000000000000000000000067` |
| Interface | `IOracleModule` (see `src/Oracle.sol`) |

## Interface

```solidity
interface IOracleModule {
    struct PricePairState {
        uint256 pairPrice;
        uint256 basePrice;
        uint256 quotePrice;
        uint256 baseCumulativePrice;
        uint256 quoteCumulativePrice;
        uint64  baseTimestamp;
        uint64  quoteTimestamp;
    }

    function oraclePrice(
        uint8 oracleType,
        string calldata base,
        string calldata quote
    ) external view returns (uint256 price);

    function oraclePricePairState(
        uint8 oracleType,
        string calldata base,
        string calldata quote
    ) external view returns (PricePairState memory state);

    function oraclePricePairStateScaled(
        uint8 oracleType,
        string calldata base,
        string calldata quote,
        uint32 baseDecimals,
        uint32 quoteDecimals
    ) external view returns (PricePairState memory state);
}
```

## Price scale

All returned prices are **1e18-scaled unsigned integers** (the raw mantissa of
Injective's internal `LegacyDec` type).  Divide by `1e18` in fixed-point
arithmetic to obtain the human-readable decimal value.

```solidity
uint256 constant PRICE_SCALE = 1e18;
uint256 rawPrice = oracle.oraclePrice(2, "BTC", "USD");
// rawPrice / PRICE_SCALE ≈ the BTC/USD spot price as a decimal
```

## Oracle type values

| Value | Oracle type | Notes |
|-------|-------------|-------|
| 2  | PriceFeed  | |
| 3  | Coinbase   | |
| 9  | Pyth       | `base` is a 0x-prefixed 32-byte price-id hex string |
| 11 | Provider   | `base` is the asset symbol; `quote` is the provider name |
| 12 | Stork      | |
| 13 | ChainlinkDataStreams | |
| 1  | Band       | **Deprecated** — always reverts |
| 4  | Chainlink  | **Deprecated** — always reverts |
| 10 | BandIBC    | **Deprecated** — always reverts |

## Key conventions

### PriceFeed / Coinbase / Stork / ChainlinkDataStreams

```
base  = asset symbol, e.g. "BTC"
quote = quote symbol, e.g. "USD"
```

### Pyth

```
base  = 0x-prefixed 32-byte price-id (hex), e.g. "0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43"
quote = "USD"   (Pyth always quotes in USD)
```

### Provider

Provider oracle keys follow the compound-key convention used by the Injective
oracle module.  The `base` field may be a plain symbol or a compound key
produced by `JoinProviderCompoundKey`, and `quote` is always the provider name.

```
base  = asset symbol or compound key
quote = provider name, e.g. "prov1"
```

## Methods

### `oraclePrice`

Returns only the pair price as a `uint256` scalar.  Sufficient for simple price
consumers that do not need timestamps or per-leg prices.

### `oraclePricePairState`

Returns the full `PricePairState` struct:

| Field | Description |
|-------|-------------|
| `pairPrice` | base/quote ratio, 1e18 scaled |
| `basePrice` | raw base-leg spot price, 1e18 scaled |
| `quotePrice` | raw quote-leg spot price, 1e18 scaled; **0** when `quote == "USD"` |
| `baseCumulativePrice` | cumulative base price for TWAP computation, 1e18 scaled |
| `quoteCumulativePrice` | cumulative quote price for TWAP computation, 1e18 scaled; **0** when `quote == "USD"` |
| `baseTimestamp` | Unix seconds of the most recent base-leg update |
| `quoteTimestamp` | Unix seconds of the most recent quote-leg update; **== baseTimestamp** when `quote == "USD"` |

Use this method when you need the update timestamp (e.g. for a Chainlink
`latestRoundData()` `updatedAt` field) or individual leg prices.

### `oraclePricePairStateScaled`

Same as `oraclePricePairState` but applies explicit decimal scaling to
`pairPrice`:

```
pairPrice = baseRate * 10^quoteDecimals / (quoteRate * 10^baseDecimals)
```

**Allowed only when:**
- `oracleType != PriceFeed (2)`
- `quote != "USD"`

Any other combination reverts with `OraclePriceNotFound`.

The individual leg prices (`basePrice`, `quotePrice`), cumulative prices, and
timestamps are **not** rescaled; only `pairPrice` is affected.

## USD-quote zero-fill convention

When `quote == "USD"`, the on-chain oracle module uses a single-leg price state
(there is no quote-side price feed for USD itself).  The precompile reflects this:

- `quotePrice` and `quoteCumulativePrice` are **0**
- `quoteTimestamp` is set to **`baseTimestamp`**

Callers building a `latestRoundData()` implementation should use
`min(baseTimestamp, quoteTimestamp)` as `updatedAt`, which collapses to
`baseTimestamp` for USD pairs.

## Error behaviour

All methods revert with an `OraclePriceNotFound` error when:

- No price has been posted for the requested `(oracleType, base, quote)` triple.
- A deprecated oracle type (Band=1, Chainlink=4, BandIBC=10) is requested.
- An unrecognised `oracleType` value is passed.
- `oraclePricePairStateScaled` is called with `oracleType == PriceFeed` or `quote == "USD"`.

## Example: Chainlink AggregatorV3Interface wrapper

The following example demonstrates how to wrap the precompile to implement
Chainlink's `latestRoundData()`.  This covers the majority of Chainlink
consumers (Aave v3, Morpho, etc.) that only call `latestRoundData()`.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Oracle.sol";

/// @notice Minimal Chainlink AggregatorV3Interface implementation backed by
///         the Injective oracle precompile.
///
/// @dev Deploy one instance per market pair.  Constructor arguments:
///        oracleType_  — numeric oracle type (e.g. 2 for PriceFeed)
///        base_        — base asset symbol (e.g. "BTC")
///        quote_       — quote asset symbol (e.g. "USD")
///        decimals_    — number of decimals to report (e.g. 8)
///
///      The precompile returns prices as 1e18-scaled uint256 values.  This
///      wrapper rescales to the declared decimals_ precision.
contract InjectiveChainlinkFeed {
    IOracleModule constant ORACLE =
        IOracleModule(0x0000000000000000000000000000000000000067);

    uint256 constant PRICE_SCALE = 1e18;

    uint8 public immutable decimals;
    string public description;

    uint8  private immutable _oracleType;
    string private _base;
    string private _quote;

    constructor(
        uint8  oracleType_,
        string memory base_,
        string memory quote_,
        uint8  decimals_,
        string memory description_
    ) {
        _oracleType  = oracleType_;
        _base        = base_;
        _quote       = quote_;
        decimals     = decimals_;
        description  = description_;
    }

    function version() external pure returns (uint256) { return 1; }

    /// @notice Returns the latest price data in Chainlink format.
    ///
    /// @dev roundId and answeredInRound are derived from updatedAt (unix
    ///      seconds) as a stable monotonic approximation.  Two updates within
    ///      the same second produce the same roundId; this is acceptable for
    ///      the use-cases this wrapper targets.
    function latestRoundData()
        external
        view
        returns (
            uint80  roundId,
            int256  answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80  answeredInRound
        )
    {
        IOracleModule.PricePairState memory state =
            ORACLE.oraclePricePairState(_oracleType, _base, _quote);

        // Rescale from 1e18 to the declared decimals precision.
        uint256 scaledPrice =
            state.pairPrice * (10 ** uint256(decimals)) / PRICE_SCALE;

        // Use the stalest leg's timestamp as updatedAt.
        updatedAt = state.baseTimestamp < state.quoteTimestamp
            ? state.baseTimestamp
            : state.quoteTimestamp;

        roundId        = uint80(updatedAt);
        answer         = int256(scaledPrice);
        startedAt      = updatedAt;
        answeredInRound = roundId;
    }

    function getRoundData(uint80)
        external
        pure
        returns (uint80, int256, uint256, uint256, uint80)
    {
        revert("historical rounds not supported");
    }
}
```
