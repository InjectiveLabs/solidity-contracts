## Solidity Contracts

This repository contains a collection of Solidity contracts that can be used to interact with the Injective blockchain.

Examples for how to use these contracts can be found in the [demos](demos) directory. The repo itself is a Foundry project, so you can use the `forge` command to compile and deploy the contracts. Also, can be included in your own Foundry project as a dependency.

### ERC20 Multi-VM Token Standard (Bank Precompile)

Injective implements its multi-vm token standard (MTS) for ERC-20 tokens using the Bank precompile, which connects EVM-based smart contracts to the native `x/bank` module. This eliminates double-accounting and enables seamless interoperability between the EVM and native chain state. The standard includes ready-to-use contracts like `BankERC20`, `FixedSupplyBankERC20`, and `MintBurnBankERC20`.

For more details, see the [ERC20 Multi-VM Token Standard documentation](docs/erc20_multivm_token_standard.md) and try out the [ERC20 demo](demos/erc20/README.md).


### Exchange Precompile

The Exchange Precompile provides a system smart contract interface for interacting with Injective's exchange module directly from Solidity. It enables smart contracts to perform actions like deposits/withdrawals, order management, balance queries, and authorization handling. The precompile can be accessed directly by contracts managing their own funds, or through a proxy pattern for contracts acting on behalf of users.

For more details, see the [Exchange Precompile documentation](docs/exchange_precompile.md) and try out the [Exchange demo](demos/exchange/README.md).


### Staking Precompile

The Staking Precompile provides a system smart contract interface for interacting with Injective's staking module directly from Solidity. It enables smart contracts to perform staking operations like delegating tokens to validators, undelegating, redelegating between validators, querying delegation data, and withdrawing staking rewards.

For more details, see the [Staking Precompile documentation](docs/staking_precompile.md) and try out the [Staking demo](demos/staking/README.md).

### IBC Transfer Precompile

The IBC Transfer Precompile at `0x0000000000000000000000000000000000000069` allows EVM accounts and contracts to initiate synchronous ICS-20 transfers using mapped Multi-VM Token Standard assets. The caller becomes the authenticated IBC sender, and the packet sequence is returned to the calling contract.

For the proposed interface and transfer semantics, see the [IBC Transfer Precompile documentation](docs/ibc_precompile.md).

### Swap Precompile

The Swap Precompile at `0x0000000000000000000000000000000000000068` executes spot swaps against Injective's on-chain orderbook from EVM accounts and contracts. It works like an AMM router: quote, set a minimum output and a deadline, then swap in a single call. The V2 methods report how much of the input was actually spent, so a contract can detect a partial fill on a thin book.

For more details, see the [Swap Precompile documentation](docs/swap_precompile.md) and try out the [Swap demo](demos/swap/README.md).

## Pre-signed Transactions

### WINJ9

WINJ9 is a pre-deployed contract that allows users to wrap INJ tokens into WINJ tokens. Deployment on a new chain requires a pre-signed non-EIP155 transaction that can be obtained by running the `utils/winj9_predeploy.sh` script (requires Node.js and Foundry).

```bash
export ETH_PRIVATE_KEY=0x...

./utils/winj9_predeploy.sh
```

The script will output the pre-signed transaction, which can be used to deploy the contract.

* WINJ9 universal address: `0x0000000088827d2d103ee2d9a6b781773ae03ffb`
* WINJ9 deployment transaction hash: `0xaf072dcb6775faaeea4a2bfa99b93ecdc08f7197ecde2d0e44cb8d57702e43a8`

## License

This project is licensed under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.
