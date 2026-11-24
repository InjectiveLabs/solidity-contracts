// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {IOracleModule} from "../Oracle.sol";
import {OracleTest} from "./OracleTest.sol";

// Retain the original return layout to exercise callers compiled against it.
interface ILegacyOracleModule {
    struct PricePairState {
        uint256 pairPrice;
        uint256 basePrice;
        uint256 quotePrice;
        uint256 baseCumulativePrice;
        uint256 quoteCumulativePrice;
        uint64 baseTimestamp;
        uint64 quoteTimestamp;
    }

    function oraclePricePairState(uint8 oracleType, string calldata base, string calldata quote)
        external
        view
        returns (PricePairState memory);

    function oraclePricePairStateScaled(
        uint8 oracleType,
        string calldata base,
        string calldata quote,
        uint32 baseDecimals,
        uint32 quoteDecimals
    ) external view returns (PricePairState memory);
}

contract OraclePricePairStateTest is Test {
    address internal constant ORACLE_PRECOMPILE = 0x0000000000000000000000000000000000000067;
    uint8 internal constant ORACLE_TYPE_PYTH_PRO = 14;

    OracleTest internal caller;

    function setUp() public {
        vm.etch(ORACLE_PRECOMPILE, hex"00");
        caller = new OracleTest();
        bytes memory response = abi.encode(_state());
        vm.mockCall(
            ORACLE_PRECOMPILE,
            abi.encodeCall(IOracleModule.oraclePricePairState, (ORACLE_TYPE_PYTH_PRO, "922", "7")),
            response
        );
        vm.mockCall(
            ORACLE_PRECOMPILE,
            abi.encodeCall(IOracleModule.oraclePricePairStateScaled, (ORACLE_TYPE_PYTH_PRO, "922", "7", 6, 18)),
            response
        );
    }

    function test_PairStateDecodesSourceTimestamps() public view {
        bytes memory expected = abi.encode(_state());
        assertEq(abi.encode(caller.oraclePricePairState(ORACLE_TYPE_PYTH_PRO, "922", "7")), expected);
        assertEq(abi.encode(caller.oraclePricePairStateViaStaticCall(ORACLE_TYPE_PYTH_PRO, "922", "7")), expected);
    }

    function test_ScaledPairStateDecodesSourceTimestamps() public view {
        bytes memory expected = abi.encode(_state());
        assertEq(abi.encode(caller.oraclePricePairStateScaled(ORACLE_TYPE_PYTH_PRO, "922", "7", 6, 18)), expected);
        assertEq(
            abi.encode(caller.oraclePricePairStateScaledViaStaticCall(ORACLE_TYPE_PYTH_PRO, "922", "7", 6, 18)),
            expected
        );
    }

    function test_LegacyCallersDecodeExtendedResponse() public view {
        ILegacyOracleModule legacy = ILegacyOracleModule(ORACLE_PRECOMPILE);
        _assertLegacyState(legacy.oraclePricePairState(ORACLE_TYPE_PYTH_PRO, "922", "7"));
        _assertLegacyState(legacy.oraclePricePairStateScaled(ORACLE_TYPE_PYTH_PRO, "922", "7", 6, 18));
        _assertLegacyState(abi.decode(abi.encode(_state()), (ILegacyOracleModule.PricePairState)));
    }

    function test_ExtendedCallerRejectsLegacyResponse() public {
        IOracleModule.PricePairState memory state = _state();
        bytes memory response = abi.encode(
            state.pairPrice,
            state.basePrice,
            state.quotePrice,
            state.baseCumulativePrice,
            state.quoteCumulativePrice,
            state.baseTimestamp,
            state.quoteTimestamp
        );
        vm.mockCall(
            ORACLE_PRECOMPILE,
            abi.encodeCall(IOracleModule.oraclePricePairState, (ORACLE_TYPE_PYTH_PRO, "922", "7")),
            response
        );
        (bool success,) =
            address(caller).call(abi.encodeCall(OracleTest.oraclePricePairState, (ORACLE_TYPE_PYTH_PRO, "922", "7")));
        assertFalse(success);
    }

    function _state() internal pure returns (IOracleModule.PricePairState memory) {
        return IOracleModule.PricePairState({
            pairPrice: 200e18,
            basePrice: 201e18,
            quotePrice: 1.005e18,
            baseCumulativePrice: 400e18,
            quoteCumulativePrice: 5e18,
            baseTimestamp: 1_700_000_100,
            quoteTimestamp: 1_700_000_101,
            baseSourceTimestamp: 1_700_000_000,
            quoteSourceTimestamp: 1_700_000_090
        });
    }

    function _assertLegacyState(ILegacyOracleModule.PricePairState memory actual) internal pure {
        IOracleModule.PricePairState memory expected = _state();
        assertEq(actual.pairPrice, expected.pairPrice);
        assertEq(actual.basePrice, expected.basePrice);
        assertEq(actual.quotePrice, expected.quotePrice);
        assertEq(actual.baseCumulativePrice, expected.baseCumulativePrice);
        assertEq(actual.quoteCumulativePrice, expected.quoteCumulativePrice);
        assertEq(actual.baseTimestamp, expected.baseTimestamp);
        assertEq(actual.quoteTimestamp, expected.quoteTimestamp);
    }
}
