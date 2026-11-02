// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISwapModule} from "../src/Swap.sol";

/// @title SwapDemo
/// @notice A contract that swaps its own funds through the swap precompile.
/// @dev The precompile debits the CALLER's bank balance, so this contract must
///      hold the input tokens. address(0) stands for native INJ, whose bank
///      balance is the contract's EVM balance.
contract SwapDemo {
    ISwapModule public constant SWAP = ISwapModule(0x0000000000000000000000000000000000000068);

    address public immutable OWNER;

    /// @param amountInSpent What the precompile reported; 0 for V1, which does
    ///        not report it.
    /// @param balanceDebited What actually left this contract's balance. It
    ///        can be one unit below amountInSpent (exchange dust, see
    ///        ISwapModule) and is below amountIn on a partial fill.
    event SwappedExactInput(
        string method,
        address tokenIn,
        uint256 amountIn,
        uint256 amountInSpent,
        uint256 amountOut,
        uint256 balanceDebited
    );

    event SwappedExactOutput(
        address tokenOut,
        uint256 amountOut,
        uint256 maxAmountIn,
        uint256 amountInSpent,
        uint256 amountOutDelivered
    );

    /// @notice The book absorbed less of amountIn than the caller accepts.
    error PartialFill(uint256 amountIn, uint256 amountInSpent, uint256 maxUnspent);
    error NotOwner();
    error TransferFailed();

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    constructor() {
        OWNER = msg.sender;
    }

    /// @notice Accepts INJ so the contract can sell it.
    receive() external payable {}

    /***************************************************************************
     * quotes (read-only passthroughs)
     **************************************************************************/

    function quoteExactInputV1(
        address tokenIn,
        string calldata marketId,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        return SWAP.quoteExactInputV1(tokenIn, marketId, amountIn);
    }

    function quoteExactInputV2(
        address tokenIn,
        string calldata marketId,
        uint256 amountIn
    ) external view returns (uint256 amountInSpent, uint256 amountOut) {
        return SWAP.quoteExactInputV2(tokenIn, marketId, amountIn);
    }

    function quoteExactOutputV1(
        address tokenOut,
        string calldata marketId,
        uint256 amountOut
    ) external view returns (uint256 amountIn) {
        return SWAP.quoteExactOutputV1(tokenOut, marketId, amountOut);
    }

    /***************************************************************************
     * swaps
     **************************************************************************/

    /// @notice Legacy exact-input swap. A partial fill is only visible through
    ///         the balance change; the precompile reports amountOut alone.
    function swapExactInputV1(
        address tokenIn,
        string calldata marketId,
        uint256 amountIn,
        uint256 minOut,
        address recipient,
        uint256 deadline
    ) external onlyOwner returns (uint256 amountOut) {
        uint256 balanceBefore = _balanceOf(tokenIn);
        amountOut = SWAP.swapExactInputV1(tokenIn, marketId, amountIn, minOut, recipient, deadline);
        emit SwappedExactInput(
            "swapExactInputV1", tokenIn, amountIn, 0, amountOut, balanceBefore - _balanceOf(tokenIn)
        );
    }

    /// @notice Exact-input swap that reverts when more than `maxUnspent` of
    ///         `amountIn` is left unfilled.
    /// @dev Pass type(uint256).max to accept any partial fill. Do not pass 0
    ///      to demand a full fill: fills are floored to the market's quantity
    ///      tick, so a full fill can still leave a sub-tick remainder. Size
    ///      `maxUnspent` from the tick, or from quoteExactInputV2 off-chain.
    ///      The revert also rolls back the swap.
    function swapExactInputV2(
        address tokenIn,
        string calldata marketId,
        uint256 amountIn,
        uint256 minOut,
        uint256 maxUnspent,
        address recipient,
        uint256 deadline
    ) external onlyOwner returns (uint256 amountInSpent, uint256 amountOut) {
        (amountInSpent, amountOut) = _swapExactInputV2(tokenIn, marketId, amountIn, minOut, recipient, deadline);
        if (amountIn - amountInSpent > maxUnspent) {
            revert PartialFill(amountIn, amountInSpent, maxUnspent);
        }
    }

    /// @notice Buys or sells for at least `amountOut` of `tokenOut`, paying at
    ///         most `maxAmountIn` of the market's other token. Never partial.
    function swapExactOutputV1(
        address tokenOut,
        string calldata marketId,
        uint256 amountOut,
        uint256 maxAmountIn,
        address recipient,
        uint256 deadline
    ) external onlyOwner returns (uint256 amountInSpent, uint256 amountOutDelivered) {
        (amountInSpent, amountOutDelivered) =
            SWAP.swapExactOutputV1(tokenOut, marketId, amountOut, maxAmountIn, recipient, deadline);
        emit SwappedExactOutput(tokenOut, amountOut, maxAmountIn, amountInSpent, amountOutDelivered);
    }

    /***************************************************************************
     * funds
     **************************************************************************/

    /// @notice Sends tokens (or INJ for address(0)) held by this contract.
    function withdraw(address token, address to, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            (bool ok,) = payable(to).call{value: amount}("");
            if (!ok) revert TransferFailed();
        } else if (!IERC20(token).transfer(to, amount)) {
            revert TransferFailed();
        }
    }

    function _swapExactInputV2(
        address tokenIn,
        string calldata marketId,
        uint256 amountIn,
        uint256 minOut,
        address recipient,
        uint256 deadline
    ) internal returns (uint256 amountInSpent, uint256 amountOut) {
        uint256 balanceBefore = _balanceOf(tokenIn);
        (amountInSpent, amountOut) =
            SWAP.swapExactInputV2(tokenIn, marketId, amountIn, minOut, recipient, deadline);
        emit SwappedExactInput(
            "swapExactInputV2", tokenIn, amountIn, amountInSpent, amountOut, balanceBefore - _balanceOf(tokenIn)
        );
    }

    function _checkOwner() internal view {
        if (msg.sender != OWNER) revert NotOwner();
    }

    function _balanceOf(address token) internal view returns (uint256) {
        return token == address(0) ? address(this).balance : IERC20(token).balanceOf(address(this));
    }
}
