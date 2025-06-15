## Solidity Contracts

This repository contains a collection of Solidity contracts that can be used to interact with the Injective blockchain.

Examples for how to use these contracts can be found in the [demos](demos) directory. The repo itself is a Foundry project, so you can use the `forge` command to compile and deploy the contracts. Also, can be included in your own Foundry project as a dependency.

### ERC20 Multi-Token Standard (Bank Precompile)

Injective implements its multi-token standard for ERC-20 tokens using the Bank precompile, which connects EVM-based smart contracts to the native `x/bank` module. This eliminates double-accounting and enables seamless interoperability between the EVM and native chain state. The standard includes ready-to-use contracts like `BankERC20`, `FixedSupplyBankERC20`, and `MintBurnBankERC20`.

For more details, see the [ERC20 Multi-Token Standard documentation](docs/erc20_multi_token_standard.md) and try out the [ERC20 demo](demos/erc20/README.md).


### Exchange Precompile

The Exchange Precompile provides a system smart contract interface for interacting with Injective's exchange module directly from Solidity. It enables smart contracts to perform actions like deposits/withdrawals, order management, balance queries, and authorization handling. The precompile can be accessed directly by contracts managing their own funds, or through a proxy pattern for contracts acting on behalf of users.

For more details, see the [Exchange Precompile documentation](docs/exchange_precompile.md) and try out the [Exchange demo](demos/exchange/README.md).


### Staking Precompile

The Staking Precompile provides a system smart contract interface for interacting with Injective's staking module directly from Solidity. It enables smart contracts to perform staking operations like delegating tokens to validators, undelegating, redelegating between validators, querying delegation data, and withdrawing staking rewards.

For more details, see the [Staking Precompile documentation](docs/staking_precompile.md) and try out the [Staking demo](demos/staking/README.md).


## License

This project is licensed under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.
