# Exchange Precompile Demo

This demo shows how to write a smart-contract that uses the exchange precompile, 
and how this smart-contract can be deployed and called using commonly used tools 
like `forge` and `cast`.

This demo goes through the following steps

1) Deposit funds in the trader's subaccount
2) Deploy `ExchangeProxy` contract
3) Create a grant from trader to contract for placing derivative limit orders
4) Call the proxy contract to place an order
5) Check that the order was created

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