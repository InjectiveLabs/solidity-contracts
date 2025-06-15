# Exchange Precompile Demo

This demo shows how to write a smart-contract that uses the exchange precompile, 
and how this smart-contract can be deployed and called using commonly used tools 
like `forge` and `cast`.

This demo goes through the following steps

1) deploy `ExchangeDemo` contract
2) Fund the contract account with some USDT
3) Call the smart-contract to deposit some USDT into the contract's subaccount
4) Check contract deposits via contract query
5) Call the smart-contract to withdraw some USDT from the contract's subaccount
6) Check contract deposits again to check the withdrawal worked
6) Call the smart-contract to create a derivative limit order using contract's deposit
7) Check that the order was created

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