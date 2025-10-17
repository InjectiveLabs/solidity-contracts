# Staking Precompile Demo

This demo shows how to deploy and interact with a smart-contract that uses the 
staking precompile using `cast` and `foundry`.

This demo goes through the following steps

1) deploy `StakingTest` contract
2) Fund the contract account with some INJ
3) Call the smart-contract to stake 100 INJ with a validator
4) Query contract delegations via staking module and precompile
5) Call the smart-contract to undelegate 50 INJ
6) Check contract undelegations via staking module
6) Call the smart-contract to withdraw delegator rewards
7) Check contract balances to show that INJ balance was incremented with staking rewards

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
git clone -b v1.16.4 https://github.com/InjectiveFoundation/injective-core 
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
