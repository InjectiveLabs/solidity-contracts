# Exchange Precompile Demo - Proxy Contract Method

This demo demonstrates the **exchange-proxy** method, which differs from the **exchange-direct** method:

- **Exchange-Direct**: The end user directly calls the exchange precompile functions from their wallet
- **Exchange-Proxy**: The end user grants authorization to a smart contract, which then calls the exchange precompile on their behalf

This proxy method is useful for:
- Creating more complex trading logic in smart contracts
- Implementing automated trading strategies
- Building DeFi protocols that need to trade on behalf of users
- Batching multiple operations together

The key concept here is **authorization grants** - the end user must explicitly grant the proxy contract permission to trade on their behalf using Cosmos SDK's authz module.

This demo goes through the following steps:

1) Deposit funds in the trader's subaccount
2) Deploy `ExchangeProxy` contract
3) Create a grant from trader to contract for placing derivative limit orders
4) Call the proxy contract to place an order
5) Check that the order was created
6) Verify that the spendable limit of the grant has decreased after the order submission

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