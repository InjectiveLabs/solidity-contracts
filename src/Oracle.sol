// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Injective Oracle precompile
/// @notice Read-only access to the on-chain oracle reference prices.
/// @dev Deployed at 0x0000000000000000000000000000000000000067
interface IOracleModule {
    /// @notice Returns the reference price for a (oracleType, base, quote) triple.
    ///
    /// @dev All prices are returned as unsigned integers scaled by 1e18 (i.e. the raw
    /// mantissa of the underlying `LegacyDec` value). Divide by 1e18 to obtain the
    /// human-readable decimal price.
    ///
    /// Supported oracleType values:
    ///   2  = PriceFeed
    ///   3  = Coinbase
    ///   9  = Pyth
    ///   11 = Provider
    ///   12 = Stork
    ///   13 = ChainlinkDataStreams
    ///
    /// Deprecated / unsupported types (1=Band, 4=Chainlink, 10=BandIBC) will
    /// cause a revert with an OraclePriceNotFound error.
    ///
    /// Key conventions per oracle type:
    ///   PriceFeed / Coinbase / Stork / ChainlinkDataStreams:
    ///     base  = asset symbol (e.g. "BTC")
    ///     quote = quote symbol or "USD"
    ///   Pyth:
    ///     base  = 0x-prefixed 32-byte price-id hex string
    ///     quote = "USD" (Pyth always quotes in USD)
    ///   Provider:
    ///     base  = asset symbol (or compound key from JoinProviderCompoundKey)
    ///     quote = provider name (e.g. "prov1")
    ///
    /// @param oracleType Numeric oracle-type enum value (see above).
    /// @param base       Base asset identifier (oracle-type–dependent, see above).
    /// @param quote      Quote asset identifier (oracle-type–dependent, see above).
    /// @return price     Reference price scaled by 1e18.  Reverts if no price is available.
    function oraclePrice(
        uint8 oracleType,
        string calldata base,
        string calldata quote
    ) external view returns (uint256 price);
}
