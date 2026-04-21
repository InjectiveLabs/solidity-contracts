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
    function oraclePrice(
        uint8 oracleType,
        string calldata base,
        string calldata quote
    ) external view returns (uint256 price);
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

## Error behaviour

The call reverts with an `OraclePriceNotFound` error when:

- No price has been posted for the requested `(oracleType, base, quote)` triple.
- A deprecated oracle type (Band=1, Chainlink=4, BandIBC=10) is requested.
- An unrecognised `oracleType` value is passed.

## Example usage

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Oracle.sol";

contract PriceConsumer {
    IOracleModule constant oracle =
        IOracleModule(0x0000000000000000000000000000000000000067);

    uint256 constant PRICE_SCALE = 1e18;

    /// @return The BTC/USD price with 18-decimal precision, scaled by 1e18.
    function getBtcUsdPrice() external view returns (uint256) {
        return oracle.oraclePrice(2 /* PriceFeed */, "BTC", "USD");
    }
}
```
