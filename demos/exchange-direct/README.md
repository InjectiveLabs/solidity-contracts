# Exchange Precompile Demo - Direct Contract Trading

This demo demonstrates how to deploy and interact with a smart contract that uses Injective's Exchange Precompile. The demo walks through deploying an existing `ExchangeDemo` contract and calling its methods to perform exchange operations like deposits, withdrawals, and order creation.

The demo uses standard Ethereum development tools (`forge` and `cast`) to interact with the smart contract on a local Injective testnet.

## Trading Methods

This demo demonstrates the **exchange-direct** method, where the smart contract trades using its own funds and subaccount. The contract:
- Manages its own deposits and withdrawals
- Creates orders using its own balance
- Does not require authorization from external users

This is different from the **exchange-proxy** method (see `../exchange-proxy/` demo), where a smart contract trades on behalf of end users through authorization grants. 

**Use exchange-direct when**: Your contract needs to trade autonomously with its own funds (e.g., AMM protocols, yield farming contracts, treasury management)

**Use exchange-proxy when**: Your contract needs to execute trades on behalf of users while they retain custody of their funds

This demo goes through the following steps:

## Overview

1) deploy `ExchangeDemo` contract
2) Fund the contract account with some USDT
3) Call the smart-contract to deposit some USDT into the contract's subaccount
4) Check contract deposits via contract query
5) Call the smart-contract to withdraw some USDT from the contract's subaccount
6) Check contract deposits again to check the withdrawal worked
7) Call the smart-contract to create a derivative limit order on the INJ/USDT perpetual market using the contract's deposit
8) Check that the order was created

Note: INJ has 18 decimals and USDT has 6 decimals.

## Requirements

### Foundry

Foundry is a smart-contract development toolchain

To install:

```
curl -L https://foundry.paradigm.xyz | bash
```

If this fails, you might need to install Rust first:

```
rustup update stable
```

### Grpcurl

`grpcurl` is a command-line tool that lets you interact with gRPC servers. It's 
basically curl for gRPC servers.

```
brew install grpcurl
```

### Injectived

Build from source and run a local `injectived` node.

Clone `injectived`: 

```
git clone -b v1.16.0 https://github.com/InjectiveFoundation/injective-core 
```

Setup the genesis file:
```
cd injective-core
./setup.sh
```

Build and run `injectived`:
```
make install
INJHOME="$(pwd)/.injectived" ./injectived.sh
```

## Run the demo

```
./demo.sh
```