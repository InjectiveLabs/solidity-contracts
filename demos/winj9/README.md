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
[`demos/localnet`](../localnet/README.md) for details, keeping the chain
somewhere other than the default (`INJHOME`), using your own `injectived`
binary instead, and stopping the chain.

## Run the demo

```
cd demos/winj9
./demo.sh
```
