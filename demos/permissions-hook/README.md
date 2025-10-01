# Permissions Hook Demo

This demo shows that the permissions module calls the EVM contract hook for 
erc20 denoms.

This demo goes through the following steps:

1) Deploy `MintBurnBankERC20` contract (token contract)
2) Deploy `RestrictSpecificAddressHook` contract (permissions hook)
3) Create a permissions namespace from unauthorized user (should fail - demonstrates access control)
4) Create a permissions namespace from token owner (should succeed - linking the token to the hook)
5) Mint 666 tokens to demonstrate initial balance
6) Query balances through x/bank and EVM JSON-RPC
7) Transfer 55 tokens to an authorized address (should succeed)
8) Query balances to verify authorized transfer
9) Transfer 88 tokens to an unauthorized address (should be blocked by hook)
10) Query final balances to verify restriction enforcement


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