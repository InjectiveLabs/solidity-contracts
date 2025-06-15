# ERC20 and Multi-VM Token Standard on Injective

Injective implements its multi-vm token standard (MTS) for ERC-20 tokens using 
the Bank precompile, which connects EVM-based smart contracts to the native 
`x/bank` module. This model eliminates double-accounting and enables seamless 
interoperability between the EVM and the native chain state.

We also provide an `erc20` module that allows you to deploy ERC-20 tokens wrapping
any native assets issued via `tokenfactory` module or IBC.

## Overview

The Bank precompile allows Solidity smart contracts to interact directly with 
the native `x/bank` module of the Injective chain. By using this precompile, 
developers can implement ERC-20 tokens that are backed entirely by native chain 
balances, rather than managing a separate balance within the EVM.

Each ERC-20 token using the Bank precompile is represented on-chain with a 
special denom of the form:

```
erc20:<contract-address>
```

For example, a token deployed at `0x123...abc` will have a denom of `erc20:0x123...abc`.

## Key Properties

- Single source of truth: Tokens exist only on-chain via the `x/bank` module. 
The smart contract simply provides a view and interface for the native balances.

- No bridging required: Unlike traditional bridge-based representations, this 
model avoids dual-token setups. There is no need for wrapping/unwrapping or 
deposit/withdraw actions.

- Instant consistency: Any native bank transfer is immediately reflected in the 
ERC-20 view, and any `transfer()` call in Solidity reflects directly in the chain 
state.

## Benefits

🔒 **Secure** – No wrapped tokens or bridging logic; balances are held directly in 
the Injective chain.

🚀 **Fast and simple** – No sync delays or manual operations to keep two systems in 
balance.

🧠 **Developer-friendly** – Use familiar ERC-20 interfaces while leveraging native 
chain accounting.

## Available Contracts

Several reusable contracts are available.

| Contract                  | Description                                                               |
| ------------------------- | ------------------------------------------------------------------------- |
| [Bank.sol](../src/Bank.sol)                  | Interface for the Bank precompile                                         |
| [BankERC20.sol](../src/BankERC20.sol)	            | Abstract ERC-20 implementation backed by the Bank precompile              |
| [FixedSupplyBankERC20.sol](../src/FixedSupplyBankERC20.sol)	| ERC-20 with a fixed supply, fully decentralized (no minting or burning)   |
| [MintBurnBankERC20.sol](../src/MintBurnBankERC20.sol)	    | ERC-20 with an owner that can mint and burn tokens                        |

All implementations extend OpenZeppelin’s standard ERC20 interfaces, enabling 
easy integration and extension.

## Customise Your Own ERC-20

Developers are free to implement their own ERC-20 tokens using the Bank 
precompile interface. Start by inheriting from `BankERC20.sol`, or fork and modify 
existing implementations to suit your requirements.

## Minting ERC-20 Tokens requires a fee

Minting ERC-20 tokens creates a `x/bank` native denom, and for the first mint a fee is required.

The default fee is 1 INJ, however the value is configurable and may change in the future, you can check the current fee value by querying the `erc20` module:

```json
// injectived q erc20 params --chain-id injective-1 --output=json

{"params":{"denom_creation_fee":{"denom":"inj","amount":"1000000000000000000"}}}
```

**Key tips about the fee:**

* It's required only for the first mint of a new denom.
* Usually you can include it when deploying the ERC-20 contract, in our `MintBurnBankERC20.sol` example the constructor is payable.
* It can be sent to contract address after deployment, in a separate transaction.
* It can be included in the `mint()` function call, as `msg.value`, but it works when the method is payable.
* Finally, make sure that when a *transparent upgradeable proxy* is used, the fee is sent to the proxy address, not the implementation address.

## Example

For a full example of how to deploy and interact with our `MintBurnBankERC20.sol`
contract, which is banked entirely by `x/bank` denoms, please refer to the 
[ERC20 demo](../demos/erc20/README.md)

