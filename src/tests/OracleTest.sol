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
}
