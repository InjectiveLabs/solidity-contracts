// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Injective swap precompile
/// @notice Native spot swaps against the x/exchange orderbook.
/// @dev Deployed at 0x0000000000000000000000000000000000000068.
///
///      Shared semantics for every method:
///
///      - A token address names a bank-backed MTS token. address(0) is native
///        INJ. Other tokens resolve through a stored ERC20 token pair (peggy,
///        IBC, tokenfactory denoms) or, from v1.21.0, to the `erc20:<address>`
///        denom of an EVM-native MTS token such as USDC.
///      - `marketId` is a 0x-prefixed 32-byte hex spot market ID. The market
///        must be active and allowlisted in the exchange module's SwapParams.
///        The swap direction follows from which side of the market the token
///        resolves to.
///      - All amounts are in chain format: the token's smallest unit, i.e. its
///        ERC20 decimals.
///      - Swaps execute as atomic taker orders on the caller's default
///        subaccount and debit the caller's bank balance directly. No ERC20
///        approval is needed. Calls carrying msg.value revert.
///      - `recipient` receives the output; address(0) means the caller.
///      - `deadline` is a Unix timestamp in seconds; 0 disables it.
///      - Quotes use the undiscounted taker fee and walk the aggregated book,
///        including paused or frozen makers that live matching skips, so
///        they can be slightly optimistic on fills and conservative on fees. `minOut` (or
///        `maxAmountIn`) on execution is the binding guard.
///      - Unspent input always stays with the caller.
///
///      Rounding, which applies to every execution method:
///
///      - Fills are floored to the market's quantity tick. Even a full fill can
///        leave less than one tick's worth of `amountIn` unspent, so
///        `amountInSpent == amountIn` is not a full-fill check. Compare against
///        quoteExactInputV2 instead.
///      - The bank balance change can differ from the returned amounts by one
///        smallest unit, always in the caller's favour. A buy can debit one
///        unit less than `amountInSpent`; a sell can pay one unit on top of
///        `amountOut`. The sub-unit remainder sits as dust in the caller's
///        default subaccount and is paid out once it adds up to a whole unit.
///
///      Availability: the V1 exact-input methods and quoteExactOutputV1 since
///      v1.20.4. The V2 methods, swapExactOutputV1 and `erc20:` token
///      resolution since v1.21.0.
interface ISwapModule {
    /// @notice Projects the output of swapExactInputV1. Read-only.
    /// @dev On a book too thin for `amountIn` this returns the partial output.
    ///      Use quoteExactInputV2 to see how much of `amountIn` would be spent.
    /// @param tokenIn Token to sell; address(0) for native INJ.
    /// @param marketId Spot market ID (0x-prefixed hex).
    /// @param amountIn Input amount in chain format.
    /// @return amountOut Projected output in chain format.
    function quoteExactInputV1(
        address tokenIn,
        string calldata marketId,
        uint256 amountIn
    ) external view returns (uint256 amountOut);

    /// @notice Projects the input needed to receive at least `amountOut`.
    ///         Read-only.
    /// @dev Rounds the input up and reverts when the book cannot deliver
    ///      `amountOut`. The input token is the market's other side.
    /// @param tokenOut Token to receive; address(0) for native INJ.
    /// @param marketId Spot market ID (0x-prefixed hex).
    /// @param amountOut Desired output in chain format.
    /// @return amountIn Required input of the market's other token.
    function quoteExactOutputV1(
        address tokenOut,
        string calldata marketId,
        uint256 amountOut
    ) external view returns (uint256 amountIn);

    /// @notice Swaps up to `amountIn` of `tokenIn`.
    /// @dev Reverts if the output is below `minOut` or the deadline passed.
    ///      A book too thin for `amountIn` fills what it can and leaves the
    ///      rest with the caller WITHOUT reporting it. Prefer swapExactInputV2.
    /// @param tokenIn Token to sell; address(0) for native INJ.
    /// @param marketId Spot market ID (0x-prefixed hex).
    /// @param amountIn Maximum input in chain format.
    /// @param minOut Minimum acceptable output in chain format.
    /// @param recipient Output receiver; address(0) for the caller.
    /// @param deadline Unix seconds; 0 disables the check.
    /// @return amountOut Output delivered to `recipient`.
    function swapExactInputV1(
        address tokenIn,
        string calldata marketId,
        uint256 amountIn,
        uint256 minOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256 amountOut);

    /// @notice Projects swapExactInputV2: the input the book would absorb and
    ///         the resulting output. Read-only.
    /// @dev `amountIn - amountInSpent` above one quantity tick means the swap
    ///      would only partially fill.
    /// @param tokenIn Token to sell; address(0) for native INJ.
    /// @param marketId Spot market ID (0x-prefixed hex).
    /// @param amountIn Input amount in chain format.
    /// @return amountInSpent Input the swap would consume.
    /// @return amountOut Projected output in chain format.
    function quoteExactInputV2(
        address tokenIn,
        string calldata marketId,
        uint256 amountIn
    ) external view returns (uint256 amountInSpent, uint256 amountOut);

    /// @notice Swaps up to `amountIn` of `tokenIn` and reports what it spent.
    /// @dev Same arguments and checks as swapExactInputV1. A book too thin for
    ///      `amountIn` fills what it can; the rest stays with the caller and
    ///      shows up as `amountInSpent < amountIn`. Revert in the calling
    ///      contract if a partial fill is unacceptable.
    /// @param tokenIn Token to sell; address(0) for native INJ.
    /// @param marketId Spot market ID (0x-prefixed hex).
    /// @param amountIn Maximum input in chain format.
    /// @param minOut Minimum acceptable output in chain format.
    /// @param recipient Output receiver; address(0) for the caller.
    /// @param deadline Unix seconds; 0 disables the check.
    /// @return amountInSpent Input the swap consumed.
    /// @return amountOut Output delivered to `recipient`.
    function swapExactInputV2(
        address tokenIn,
        string calldata marketId,
        uint256 amountIn,
        uint256 minOut,
        address recipient,
        uint256 deadline
    ) external returns (uint256 amountInSpent, uint256 amountOut);

    /// @notice Delivers at least `amountOut` of `tokenOut` for at most
    ///         `maxAmountIn` of the market's other token.
    /// @dev Sizes the input with quoteExactOutputV1 and executes it with
    ///      minOut = amountOut. Reverts when the required input exceeds
    ///      `maxAmountIn` or the book cannot deliver `amountOut`; it never
    ///      fills partially. Fills happen in quantity ticks, so
    ///      `amountOutDelivered` can slightly exceed `amountOut`.
    /// @param tokenOut Token to receive; address(0) for native INJ.
    /// @param marketId Spot market ID (0x-prefixed hex).
    /// @param amountOut Minimum output in chain format.
    /// @param maxAmountIn Maximum input of the market's other token.
    /// @param recipient Output receiver; address(0) for the caller.
    /// @param deadline Unix seconds; 0 disables the check.
    /// @return amountInSpent Input the swap consumed.
    /// @return amountOutDelivered Output delivered to `recipient`.
    function swapExactOutputV1(
        address tokenOut,
        string calldata marketId,
        uint256 amountOut,
        uint256 maxAmountIn,
        address recipient,
        uint256 deadline
    ) external returns (uint256 amountInSpent, uint256 amountOutDelivered);
}
