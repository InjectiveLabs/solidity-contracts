// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {IOracleModule} from "./Oracle.sol";
import {IPyth} from "pyth-crosschain/target_chains/ethereum/sdk/solidity/IPyth.sol";
import {PythErrors} from "pyth-crosschain/target_chains/ethereum/sdk/solidity/PythErrors.sol";
import {PythStructs} from "pyth-crosschain/target_chains/ethereum/sdk/solidity/PythStructs.sol";

/// @notice Pyth IPyth-compatible wrapper backed by the Injective oracle
/// precompile.
///
/// @dev This adapter is intentionally feed-specific. It exists to satisfy the
/// official `PythAggregatorV3` contract, which expects an `IPyth` contract plus
/// a `priceId`.
///
/// Injective already stores oracle prices natively on-chain, so this adapter
/// does not implement the full stateful Pyth update/parsing workflow. The
/// payable update and parse methods below are compatibility shims only.
contract InjectivePyth is IPyth {
    IOracleModule internal constant ORACLE = IOracleModule(0x0000000000000000000000000000000000000067);

    uint256 internal constant MAX_INT64 = uint256(uint64(type(int64).max));
    uint8 internal constant PYTH_ORACLE_TYPE = 9;
    uint256 internal constant PRECOMPILE_PRICE_SCALE = 1e18;
    string internal constant PYTH_USD_QUOTE = "USD";

    bytes32 public immutable FEED_ID;
    uint8 public immutable FEED_DECIMALS;
    uint8 public immutable SOURCE_ORACLE_TYPE;
    string public sourceBase;
    string public sourceQuote;

    error RefundFailed();

    constructor(
        bytes32 feedId_,
        uint8 sourceOracleType_,
        string memory sourceBase_,
        string memory sourceQuote_,
        uint8 feedDecimals_
    ) {
        FEED_ID = feedId_;
        FEED_DECIMALS = feedDecimals_;
        SOURCE_ORACLE_TYPE = sourceOracleType_;

        if (sourceOracleType_ == PYTH_ORACLE_TYPE && bytes(sourceBase_).length == 0) {
            sourceBase = Strings.toHexString(uint256(feedId_), 32);
        } else {
            sourceBase = sourceBase_;
        }

        if (sourceOracleType_ == PYTH_ORACLE_TYPE && bytes(sourceQuote_).length == 0) {
            sourceQuote = PYTH_USD_QUOTE;
        } else {
            sourceQuote = sourceQuote_;
        }
    }

    function getPriceUnsafe(bytes32 id) external view override returns (PythStructs.Price memory price) {
        return _latestPrice(id);
    }

    function getPriceNoOlderThan(bytes32 id, uint256 age)
        external
        view
        override
        returns (PythStructs.Price memory price)
    {
        price = _latestPrice(id);
        _revertIfStale(price.publishTime, age);
    }

    function getEmaPriceUnsafe(bytes32 id) external view override returns (PythStructs.Price memory price) {
        // Partial implementation: the precompile does not expose EMA data in
        // Pyth's format, so this adapter aliases EMA reads to the latest spot
        // price instead of attempting to synthesize a separate series.
        return _latestPrice(id);
    }

    function getEmaPriceNoOlderThan(bytes32 id, uint256 age)
        external
        view
        override
        returns (PythStructs.Price memory price)
    {
        price = _latestPrice(id);
        _revertIfStale(price.publishTime, age);
    }

    function updatePriceFeeds(bytes[] calldata) external payable override {
        // No-op compatibility method. Native Injective oracle data is already
        // on-chain, so there is no signed update blob to submit here.
        _refundValue();
    }

    function updatePriceFeedsIfNecessary(bytes[] calldata, bytes32[] calldata, uint64[] calldata)
        external
        payable
        override
    {
        // No-op for the same reason as `updatePriceFeeds`.
        _refundValue();
    }

    function getUpdateFee(bytes[] calldata) external pure override returns (uint256 feeAmount) {
        // No external update payload is consumed, so there is no fee model.
        return 0;
    }

    function getTwapUpdateFee(bytes[] calldata) external pure override returns (uint256 feeAmount) {
        // TWAP update blobs are not consumed either.
        return 0;
    }

    function parsePriceFeedUpdates(bytes[] calldata, bytes32[] calldata, uint64, uint64)
        external
        payable
        override
        returns (PythStructs.PriceFeed[] memory priceFeeds)
    {
        // No-op compatibility method. This adapter does not parse Pyth update
        // messages because the price source is the native oracle precompile.
        _refundValue();
        return new PythStructs.PriceFeed[](0);
    }

    function parsePriceFeedUpdatesWithConfig(bytes[] calldata, bytes32[] calldata, uint64, uint64, bool, bool, bool)
        external
        payable
        override
        returns (PythStructs.PriceFeed[] memory priceFeeds, uint64[] memory slots)
    {
        // Same as `parsePriceFeedUpdates`: keep the ABI, return no parsed data.
        _refundValue();
        return (new PythStructs.PriceFeed[](0), new uint64[](0));
    }

    function parseTwapPriceFeedUpdates(bytes[] calldata, bytes32[] calldata)
        external
        payable
        override
        returns (PythStructs.TwapPriceFeed[] memory twapPriceFeeds)
    {
        // Partial implementation: no TWAP feed translation is provided here.
        _refundValue();
        return new PythStructs.TwapPriceFeed[](0);
    }

    function parsePriceFeedUpdatesUnique(bytes[] calldata, bytes32[] calldata, uint64, uint64)
        external
        payable
        override
        returns (PythStructs.PriceFeed[] memory priceFeeds)
    {
        // Same no-op behavior as the other parse methods.
        _refundValue();
        return new PythStructs.PriceFeed[](0);
    }

    function _latestPrice(bytes32 id) internal view returns (PythStructs.Price memory price) {
        if (id != FEED_ID) revert PythErrors.PriceFeedNotFound();

        IOracleModule.PricePairState memory state =
            ORACLE.oraclePricePairState(SOURCE_ORACLE_TYPE, sourceBase, sourceQuote);

        uint256 scaledPrice = Math.mulDiv(state.pairPrice, 10 ** uint256(FEED_DECIMALS), PRECOMPILE_PRICE_SCALE);
        if (scaledPrice > MAX_INT64) revert PythErrors.CombinedPriceOverflow();

        price = PythStructs.Price({
            // forge-lint: disable-next-line(unsafe-typecast)
            price: int64(uint64(scaledPrice)),
            conf: 0,
            expo: -int32(uint32(FEED_DECIMALS)),
            publishTime: _updatedAt(state)
        });
    }

    function _revertIfStale(uint256 publishTime, uint256 age) internal view {
        if (publishTime > block.timestamp) revert PythErrors.StalePrice();
        if (block.timestamp - publishTime > age) revert PythErrors.StalePrice();
    }

    function _updatedAt(IOracleModule.PricePairState memory state) internal pure returns (uint256) {
        return state.baseTimestamp < state.quoteTimestamp ? state.baseTimestamp : state.quoteTimestamp;
    }

    function _refundValue() internal {
        if (msg.value == 0) return;

        (bool success,) = payable(msg.sender).call{value: msg.value}("");
        if (!success) revert RefundFailed();
    }
}
