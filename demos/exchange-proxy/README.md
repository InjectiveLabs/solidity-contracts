# Exchange Precompile Demo - Proxy Contract Trading

This demo demonstrates how to deploy and interact with a smart contract that uses Injective's Exchange Precompile with authorization grants. The demo walks through deploying an existing `ExchangeProxy` contract and using it to trade on behalf of users through the authz system.

The demo uses standard Ethereum development tools (`forge` and `cast`) to interact with the smart contract on a local Injective testnet.

## Trading Methods

This demo demonstrates the **exchange-proxy** method, where a smart contract trades on behalf of end users through authorization grants. The contract:
- Requires explicit authorization grants from users
- Executes trades using users' funds and subaccounts
- Manages spend limits through the authz system
- Allows users to retain custody of their funds

This is different from the **exchange-direct** method (see `../exchange-direct/` demo), where the smart contract trades using its own funds and subaccount.

**Use exchange-proxy when**: Your contract needs to execute trades on behalf of users while they retain custody of their funds (e.g., trading bots, portfolio management, complex order strategies)

**Use exchange-direct when**: Your contract needs to trade autonomously with its own funds (e.g., AMM protocols, yield farming contracts, treasury management)

## Overview

1) Deposit funds in the trader's subaccount
2) Deploy `ExchangeProxy` contract
3) Create a grant from trader to contract for placing derivative limit orders
4) Call the proxy contract to place a derivative limit order on the INJ/USDT perpetual market
5) Check that the order was created
6) Verify that the spendable limit of the grant has decreased after the order submission

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