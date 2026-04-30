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
contract InjectivePyth is IPyth {
    IOracleModule internal constant ORACLE =
        IOracleModule(0x0000000000000000000000000000000000000067);

    uint8 internal constant PYTH_ORACLE_TYPE = 9;
    uint256 internal constant PRECOMPILE_PRICE_SCALE = 1e18;

    bytes32 public immutable FEED_ID;
    uint8 public immutable FEED_DECIMALS;
    uint8 public immutable SOURCE_ORACLE_TYPE;
    string public sourceBase;
    string public sourceQuote;

    error UnsupportedPythMethod();

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
            sourceQuote = "USD";
        } else {
            sourceQuote = sourceQuote_;
        }
    }

    function getPriceUnsafe(
        bytes32 id
    ) external view override returns (PythStructs.Price memory price) {
        return _latestPrice(id);
    }

    function getPriceNoOlderThan(
        bytes32 id,
        uint age
    ) external view override returns (PythStructs.Price memory price) {
        price = _latestPrice(id);
        if (block.timestamp > price.publishTime + age) revert PythErrors.StalePrice();
    }

    function getEmaPriceUnsafe(
        bytes32
    ) external pure override returns (PythStructs.Price memory) {
        revert UnsupportedPythMethod();
    }

    function getEmaPriceNoOlderThan(
        bytes32,
        uint
    ) external pure override returns (PythStructs.Price memory) {
        revert UnsupportedPythMethod();
    }

    function updatePriceFeeds(bytes[] calldata) external payable override {
        _refundValue();
    }

    function updatePriceFeedsIfNecessary(
        bytes[] calldata,
        bytes32[] calldata,
        uint64[] calldata
    ) external payable override {
        _refundValue();
    }

    function getUpdateFee(
        bytes[] calldata
    ) external pure override returns (uint feeAmount) {
        return 0;
    }

    function getTwapUpdateFee(
        bytes[] calldata
    ) external pure override returns (uint feeAmount) {
        return 0;
    }

    function parsePriceFeedUpdates(
        bytes[] calldata,
        bytes32[] calldata,
        uint64,
        uint64
    ) external payable override returns (PythStructs.PriceFeed[] memory) {
        revert UnsupportedPythMethod();
    }

    function parsePriceFeedUpdatesWithConfig(
        bytes[] calldata,
        bytes32[] calldata,
        uint64,
        uint64,
        bool,
        bool,
        bool
    ) external payable override returns (PythStructs.PriceFeed[] memory, uint64[] memory) {
        revert UnsupportedPythMethod();
    }

    function parseTwapPriceFeedUpdates(
        bytes[] calldata,
        bytes32[] calldata
    ) external payable override returns (PythStructs.TwapPriceFeed[] memory) {
        revert UnsupportedPythMethod();
    }

    function parsePriceFeedUpdatesUnique(
        bytes[] calldata,
        bytes32[] calldata,
        uint64,
        uint64
    ) external payable override returns (PythStructs.PriceFeed[] memory) {
        revert UnsupportedPythMethod();
    }

    function _latestPrice(bytes32 id) internal view returns (PythStructs.Price memory price) {
        if (id != FEED_ID) revert PythErrors.PriceFeedNotFound();

        IOracleModule.PricePairState memory state =
            ORACLE.oraclePricePairState(SOURCE_ORACLE_TYPE, sourceBase, sourceQuote);

        uint256 scaledPrice = Math.mulDiv(
            state.pairPrice,
            10 ** uint256(FEED_DECIMALS),
            PRECOMPILE_PRICE_SCALE
        );
        if (scaledPrice > uint256(uint64(type(int64).max))) revert PythErrors.CombinedPriceOverflow();

        uint256 publishTime = state.baseTimestamp < state.quoteTimestamp ? state.baseTimestamp : state.quoteTimestamp;

        price = PythStructs.Price({
            // forge-lint: disable-next-line(unsafe-typecast)
            price: int64(uint64(scaledPrice)),
            conf: 0,
            expo: -int32(uint32(FEED_DECIMALS)),
            publishTime: publishTime
        });
    }

    function _refundValue() internal {
        if (msg.value == 0) return;

        (bool success, ) = payable(msg.sender).call{value: msg.value}("");
        require(success, "refund failed");
    }
}
