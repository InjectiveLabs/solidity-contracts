// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {IOracleModule} from "../Oracle.sol";
import {InjectiveMorphoAggregatorV3} from "../InjectiveMorphoAggregatorV3.sol";
import {InjectivePyth} from "../InjectivePyth.sol";
import {PythAggregatorV3} from "pyth-crosschain/target_chains/ethereum/sdk/solidity/PythAggregatorV3.sol";
import {PythStructs} from "pyth-crosschain/target_chains/ethereum/sdk/solidity/PythStructs.sol";
import {MorphoChainlinkOracleV2} from "morpho-blue-oracles/src/morpho-chainlink/MorphoChainlinkOracleV2.sol";
import {AggregatorV3Interface} from "morpho-blue-oracles/src/morpho-chainlink/interfaces/AggregatorV3Interface.sol";
import {IERC4626} from "morpho-blue-oracles/src/morpho-chainlink/libraries/VaultLib.sol";

contract MockOraclePrecompile is IOracleModule {
    mapping(bytes32 => PricePairState) internal states;

    function setPricePairState(
        uint8 oracleType,
        string calldata base,
        string calldata quote,
        PricePairState calldata state
    ) external {
        states[_key(oracleType, base, quote)] = state;
    }

    function oraclePrice(
        uint8 oracleType,
        string calldata base,
        string calldata quote
    ) external view returns (uint256 price) {
        return states[_key(oracleType, base, quote)].pairPrice;
    }

    function oraclePricePairState(
        uint8 oracleType,
        string calldata base,
        string calldata quote
    ) external view returns (PricePairState memory state) {
        return states[_key(oracleType, base, quote)];
    }

    function oraclePricePairStateScaled(
        uint8 oracleType,
        string calldata base,
        string calldata quote,
        uint32,
        uint32
    ) external view returns (PricePairState memory state) {
        return states[_key(oracleType, base, quote)];
    }

    function _key(
        uint8 oracleType,
        string calldata base,
        string calldata quote
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(oracleType, base, quote));
    }
}

contract InjectiveOracleWrappersTest is Test {
    address internal constant ORACLE_PRECOMPILE = 0x0000000000000000000000000000000000000067;

    uint8 internal constant ORACLE_TYPE_PYTH = 9;
    uint8 internal constant ORACLE_TYPE_CHAINLINK_DATA_STREAMS = 13;

    bytes32 internal constant PYTH_BTC_USD_ID =
        0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43;
    bytes32 internal constant PYTH_USDC_USD_ID =
        0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfcfdb74db759d5e0b3;
    bytes32 internal constant SYNTHETIC_CHAINLINK_BTC_USD_ID =
        keccak256("injective:chainlink:btc-usd");

    MockOraclePrecompile internal oraclePrecompile;

    function setUp() public {
        MockOraclePrecompile mock = new MockOraclePrecompile();
        vm.etch(ORACLE_PRECOMPILE, address(mock).code);
        oraclePrecompile = MockOraclePrecompile(ORACLE_PRECOMPILE);
    }

    function test_OfficialPythAggregatorV3_WorksWithNativePythSource() public {
        oraclePrecompile.setPricePairState(
            ORACLE_TYPE_PYTH,
            "0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43",
            "USD",
            IOracleModule.PricePairState({
                pairPrice: 42_000e18,
                basePrice: 42_000e18,
                quotePrice: 0,
                baseCumulativePrice: 0,
                quoteCumulativePrice: 0,
                baseTimestamp: 1_717_171_717,
                quoteTimestamp: 1_717_171_717
            })
        );

        InjectivePyth injectivePyth = new InjectivePyth(
            PYTH_BTC_USD_ID,
            ORACLE_TYPE_PYTH,
            "",
            "",
            8
        );
        PythAggregatorV3 aggregator = new PythAggregatorV3(address(injectivePyth), PYTH_BTC_USD_ID);

        PythStructs.Price memory rawPrice = injectivePyth.getPriceUnsafe(PYTH_BTC_USD_ID);

        assertEq(rawPrice.price, 4_200_000_000_000);
        assertEq(rawPrice.expo, -8);
        assertEq(rawPrice.publishTime, 1_717_171_717);
        assertEq(aggregator.decimals(), 8);
        assertEq(aggregator.latestAnswer(), 4_200_000_000_000);
        assertEq(aggregator.latestTimestamp(), 1_717_171_717);
    }

    function test_OfficialPythAggregatorV3_WorksWithChainlinkNativeSource() public {
        oraclePrecompile.setPricePairState(
            ORACLE_TYPE_CHAINLINK_DATA_STREAMS,
            "BTC",
            "USD",
            IOracleModule.PricePairState({
                pairPrice: 42_500e18,
                basePrice: 42_500e18,
                quotePrice: 0,
                baseCumulativePrice: 0,
                quoteCumulativePrice: 0,
                baseTimestamp: 1_818,
                quoteTimestamp: 1_818
            })
        );

        InjectivePyth injectivePyth = new InjectivePyth(
            SYNTHETIC_CHAINLINK_BTC_USD_ID,
            ORACLE_TYPE_CHAINLINK_DATA_STREAMS,
            "BTC",
            "USD",
            8
        );
        PythAggregatorV3 aggregator =
            new PythAggregatorV3(address(injectivePyth), SYNTHETIC_CHAINLINK_BTC_USD_ID);

        assertEq(aggregator.decimals(), 8);
        assertEq(aggregator.latestAnswer(), 4_250_000_000_000);
        assertEq(aggregator.latestRound(), 1_818);
    }

    function test_MorphoWrapper_ExposesNativePythAsAggregatorV3() public {
        oraclePrecompile.setPricePairState(
            ORACLE_TYPE_PYTH,
            "0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43",
            "USD",
            IOracleModule.PricePairState({
                pairPrice: 42_000e18,
                basePrice: 42_000e18,
                quotePrice: 0,
                baseCumulativePrice: 0,
                quoteCumulativePrice: 0,
                baseTimestamp: 1_234_567_890,
                quoteTimestamp: 1_234_567_890
            })
        );

        InjectiveMorphoAggregatorV3 feed = new InjectiveMorphoAggregatorV3(
            ORACLE_TYPE_PYTH,
            "0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43",
            "USD",
            8,
            "Injective Pyth BTC / USD"
        );

        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = feed.latestRoundData();

        assertEq(feed.decimals(), 8);
        assertEq(answer, 4_200_000_000_000);
        assertEq(roundId, 1_234_567_890);
        assertEq(startedAt, 1_234_567_890);
        assertEq(updatedAt, 1_234_567_890);
        assertEq(answeredInRound, 1_234_567_890);
    }

    function test_OfficialMorphoChainlinkOracleV2_DeploysWithPythBackedWrapper() public {
        oraclePrecompile.setPricePairState(
            ORACLE_TYPE_PYTH,
            "0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43",
            "USD",
            IOracleModule.PricePairState({
                pairPrice: 42_000e18,
                basePrice: 42_000e18,
                quotePrice: 0,
                baseCumulativePrice: 0,
                quoteCumulativePrice: 0,
                baseTimestamp: 100,
                quoteTimestamp: 100
            })
        );

        oraclePrecompile.setPricePairState(
            ORACLE_TYPE_PYTH,
            "0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfcfdb74db759d5e0b3",
            "USD",
            IOracleModule.PricePairState({
                pairPrice: 1e18,
                basePrice: 1e18,
                quotePrice: 0,
                baseCumulativePrice: 0,
                quoteCumulativePrice: 0,
                baseTimestamp: 100,
                quoteTimestamp: 100
            })
        );

        InjectiveMorphoAggregatorV3 btcUsd = new InjectiveMorphoAggregatorV3(
            ORACLE_TYPE_PYTH,
            "0xe62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43",
            "USD",
            8,
            "Injective Pyth BTC / USD"
        );
        InjectiveMorphoAggregatorV3 usdcUsd = new InjectiveMorphoAggregatorV3(
            ORACLE_TYPE_PYTH,
            "0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfcfdb74db759d5e0b3",
            "USD",
            8,
            "Injective Pyth USDC / USD"
        );

        MorphoChainlinkOracleV2 morphoOracle = new MorphoChainlinkOracleV2(
            IERC4626(address(0)),
            1,
            AggregatorV3Interface(address(btcUsd)),
            AggregatorV3Interface(address(0)),
            8,
            IERC4626(address(0)),
            1,
            AggregatorV3Interface(address(usdcUsd)),
            AggregatorV3Interface(address(0)),
            6
        );

        uint256 expectedScaleFactor = 10 ** 34;
        uint256 expectedPrice = expectedScaleFactor * 4_200_000_000_000 / 100_000_000;

        assertEq(morphoOracle.SCALE_FACTOR(), expectedScaleFactor);
        assertEq(morphoOracle.price(), expectedPrice);
    }
}
