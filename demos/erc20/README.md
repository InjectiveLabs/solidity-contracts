# ERC20 Single Token Representation Demo

This demo shows how to deploy and interact with our `MintBurnBankERC20` contract,
which is backed entirely by native chain balances.

This demo goes through the following steps

1) deploy `MintBurnBankERC20` contract
2) Mint 666 tokens
3) Query balances through x/bank and EVM JSON-RPC
4) Transfer 555 tokens
5) Query balances again

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