// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {IOracleModule} from "./Oracle.sol";
import {AggregatorV3Interface} from "morpho-blue-oracles/src/morpho-chainlink/interfaces/AggregatorV3Interface.sol";

/// @notice Morpho-facing AggregatorV3 wrapper backed by the Injective oracle
/// precompile.
///
/// @dev This contract is meant to satisfy Morpho's
/// `AggregatorV3Interface` dependency. It exposes only the standard
/// Chainlink-compatible surface that Morpho consumes.
contract InjectiveMorphoAggregatorV3 is AggregatorV3Interface {
    IOracleModule internal constant ORACLE = IOracleModule(0x0000000000000000000000000000000000000067);

    uint256 internal constant MAX_INT256 = uint256(type(int256).max);
    uint256 internal constant PRECOMPILE_PRICE_SCALE = 1e18;
    uint256 internal constant ADAPTER_VERSION = 1;

    uint8 public immutable oracleType;
    uint8 public immutable override decimals;
    string public override description;
    string public base;
    string public quote;

    error AnswerOverflow();

    constructor(
        uint8 oracleType_,
        string memory base_,
        string memory quote_,
        uint8 decimals_,
        string memory description_
    ) {
        oracleType = oracleType_;
        decimals = decimals_;
        description = description_;
        base = base_;
        quote = quote_;
    }

    function version() external pure override returns (uint256) {
        return ADAPTER_VERSION;
    }

    function getRoundData(uint80 roundId)
        external
        view
        override
        returns (uint80 returnedRoundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (answer, updatedAt) = _latestAnswerAndTimestamp();
        return (roundId, answer, updatedAt, updatedAt, roundId);
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (answer, updatedAt) = _latestAnswerAndTimestamp();
        // forge-lint: disable-next-line(unsafe-typecast)
        roundId = uint80(updatedAt);
        return (roundId, answer, updatedAt, updatedAt, roundId);
    }

    function _latestAnswerAndTimestamp() internal view returns (int256 answer, uint256 updatedAt) {
        IOracleModule.PricePairState memory state = ORACLE.oraclePricePairState(oracleType, base, quote);
        updatedAt = _updatedAt(state);
        answer = _scaledAnswer(state.pairPrice);
    }

    function _updatedAt(IOracleModule.PricePairState memory state) internal pure returns (uint256) {
        return state.baseTimestamp < state.quoteTimestamp ? state.baseTimestamp : state.quoteTimestamp;
    }

    function _scaledAnswer(uint256 pairPrice) internal view returns (int256) {
        uint256 scaledPrice = Math.mulDiv(pairPrice, 10 ** uint256(decimals), PRECOMPILE_PRICE_SCALE);
        if (scaledPrice > MAX_INT256) revert AnswerOverflow();
        // forge-lint: disable-next-line(unsafe-typecast)
        return int256(scaledPrice);
    }
}
