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

or, on Linux (with Go):

```
go install github.com/fullstorydev/grpcurl/cmd/grpcurl@v1.9.3
```

### Local chain

The demo runs against a local Injective chain (v1.21.0 or later) from the
public `injectivelabs/injective-core` Docker image. From the repo root:

```
docker pull injectivelabs/injective-core:v1.21.0
./demos/localnet/start.sh
export PATH="$(pwd)/demos/localnet/bin:$PATH"
```

`start.sh` creates the `user1` key and funds it. The `PATH` line
makes the demo's `injectived` commands run inside the node's container. See
[`demos/localnet`](../localnet/README.md) for details, using your own
`injectived` binary instead, and stopping the chain.

## Run the demo

```
cd demos/staking
./demo.sh
```
