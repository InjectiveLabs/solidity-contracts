// SPDX-License-Identifier: MIT
pragma solidity >0.6.6;

import "../Oracle.sol";

/// @dev Thin wrapper used by Go integration tests.
///      Forwards calls to the oracle precompile at address 0x67.
contract OracleTest {
    address constant oracleContract = 0x0000000000000000000000000000000000000067;
    IOracleModule oracle = IOracleModule(oracleContract);

    /// @dev Calls the precompile via a regular CALL (non-static context).
    function oraclePrice(
        uint8 oracleType,
        string memory base,
        string memory quote
    ) external view returns (uint256) {
        return oracle.oraclePrice(oracleType, base, quote);
    }

    /// @dev Calls the precompile via an explicit STATICCALL, exercising the
    ///      read-only execution path.
    function oraclePriceViaStaticCall(
        uint8 oracleType,
        string memory base,
        string memory quote
    ) external view returns (uint256 price) {
        bytes memory data = abi.encodeWithSelector(
            IOracleModule.oraclePrice.selector,
            oracleType,
            base,
            quote
        );
        (bool success, bytes memory result) = oracleContract.staticcall(data);
        require(success, "staticcall failed");
        price = abi.decode(result, (uint256));
    }

    /// @dev Calls oraclePricePairState via a regular CALL.
    function oraclePricePairState(
        uint8 oracleType,
        string memory base,
        string memory quote
    ) external view returns (IOracleModule.PricePairState memory) {
        return oracle.oraclePricePairState(oracleType, base, quote);
    }

    /// @dev Calls oraclePricePairState via an explicit STATICCALL.
    function oraclePricePairStateViaStaticCall(
        uint8 oracleType,
        string memory base,
        string memory quote
    ) external view returns (IOracleModule.PricePairState memory state) {
        bytes memory data = abi.encodeWithSelector(
            IOracleModule.oraclePricePairState.selector,
            oracleType,
            base,
            quote
        );
        (bool success, bytes memory result) = oracleContract.staticcall(data);
        require(success, "staticcall failed");
        state = abi.decode(result, (IOracleModule.PricePairState));
    }

    /// @dev Calls oraclePricePairStateScaled via a regular CALL.
    function oraclePricePairStateScaled(
        uint8 oracleType,
        string memory base,
        string memory quote,
        uint32 baseDecimals,
        uint32 quoteDecimals
    ) external view returns (IOracleModule.PricePairState memory) {
        return oracle.oraclePricePairStateScaled(oracleType, base, quote, baseDecimals, quoteDecimals);
    }

    /// @dev Calls oraclePricePairStateScaled via an explicit STATICCALL.
    function oraclePricePairStateScaledViaStaticCall(
        uint8 oracleType,
        string memory base,
        string memory quote,
        uint32 baseDecimals,
        uint32 quoteDecimals
    ) external view returns (IOracleModule.PricePairState memory state) {
        bytes memory data = abi.encodeWithSelector(
            IOracleModule.oraclePricePairStateScaled.selector,
            oracleType,
            base,
            quote,
            baseDecimals,
            quoteDecimals
        );
        (bool success, bytes memory result) = oracleContract.staticcall(data);
        require(success, "staticcall failed");
        state = abi.decode(result, (IOracleModule.PricePairState));
    }
}
