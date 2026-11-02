# Swap Precompile Demo

This demo starts a fresh local chain and drives every method of the swap
precompile (`0x0000000000000000000000000000000000000068`) through the
[`SwapDemo`](../../examples/SwapDemo.sol) contract. `SwapDemo` swaps its own
funds and measures its own balance changes, so the demo prints what the
precompile reported next to what actually moved.

See the [Swap Precompile documentation](../../docs/swap_precompile.md) for the
full semantics.

## Overview

1) Start a single-validator chain with `dev1` as exchange admin
2) Deploy an EVM-native USDC (`MintBurnBankERC20`, 6 decimals). Its bank
   denom is `erc20:<address>` and it has no token pair
3) Launch an INJ/USDC spot market and allowlist it with `MsgUpdateSwapParams`
4) `dev2` places resting asks at 10.0 / 10.5 and bids at 9.5 / 9.0, 10 INJ each
5) Deploy `SwapDemo` and fund it with 1,000 USDC and 50 INJ
6) `quoteExactInputV1` and `quoteExactInputV2` for 50 USDC
7) `swapExactInputV2` buy with `minOut` from a limit price. The debit can
   be one unit below `amountInSpent` (exchange dust)
8) `swapExactInputV2` sell of 1.0005 INJ. This is a full fill, yet
   `amountInSpent` is 1.000 INJ because fills are floored to the 0.001 tick
9) `swapExactInputV1` sell, which reports `amountOut` only
10) `quoteExactOutputV1` + `swapExactOutputV1` for exactly 2 INJ, delivered to
    another address, followed by a `maxAmountIn` that is too low and reverts
11) Over-depth: a 500 USDC buy against ~135 USDC of asks. V1's quote looks
    normal; V2's quote shows the shortfall. A strict swap reverts with
    `PartialFill`, and a lenient one fills what it can and keeps the rest
12) Withdraw the contract's funds

## Requirements

- `injectived` **v1.21.0 or later**. The V2 methods, `swapExactOutputV1` and
  `erc20:` token resolution do not exist in v1.20.x. Until v1.21.0 is
  released, build it from `master`:

  ```
  git clone https://github.com/InjectiveLabs/injective-core
  cd injective-core && make install
  ```

- Foundry (`forge`, `cast`). Upstream Foundry works. The Injective fork adds
  bank precompile emulation to local simulation:

  ```
  cargo install --git https://github.com/InjectiveLabs/foundry --tag v1.4.4-inj.3 --locked forge cast anvil
  ```

  or upstream:

  ```
  curl -L https://foundry.paradigm.xyz | bash && foundryup
  ```

- `jq`, `python3`, and the git submodules (`git submodule update --init --recursive`).

## Run the demo

```
./demos/swap/demo.sh
```

The script needs ports 26657, 8545, 9900 and 10337 to be free. It stops the node on
exit.

| Variable | Default | Purpose |
|---|---|---|
| `INJECTIVED` | `injectived` | Path to the node binary |
| `SWAP_DEMO_HOME` | `.injectived-swap-demo` | Chain home, wiped on every run |
| `KEEP_NODE` | `0` | `1` leaves the node running afterwards |
