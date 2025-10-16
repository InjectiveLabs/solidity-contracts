// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Interface for WINJ9
interface IWINJ9 is IERC20 {
    /// @notice Deposit INJ to get wrapped INJ
    function deposit() external payable;

    /// @notice Withdraw wrapped INJ to get INJ
    function withdraw(uint256) external;
}
