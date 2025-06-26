# WINJ9 Demo

This demo shows how to deploy and interact with our `WINJ9` contract,
which is backed entirely by native chain balances.

This demo goes through the following steps:

1) Deploy `WINJ9` contract
2) Deposit 100 INJ
3) Check that we received 100 WINJ
4) Transfer 5 WINJ
5) Check balance update
6) Withdraw 50 WINJ
7) Check that we received 50 INJ

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