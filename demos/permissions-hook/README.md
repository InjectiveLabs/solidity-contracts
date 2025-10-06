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

```bash
curl -L https://foundry.paradigm.xyz | bash
```

If this fails, you might need to install Rust first:

```bash
rustup update stable
```

### Grpcurl

`grpcurl` is a command-line tool that lets you interact with gRPC servers. It's
basically curl for gRPC servers.

```bash
brew install grpcurl
```

### Injectived

Build from source and run a local `injectived` node.

Clone `injectived`:

```bash
git clone https://github.com/InjectiveFoundation/injective-core
```

Setup the genesis file:
```bash
cd injective-core
./setup.sh
```

Build and run `injectived`:
```bash
make install
INJHOME="$(pwd)/.injectived" ./injectived.sh
```

## Run the demo

Warning! Make sure to set the same `$INJHOME` env for bash session where you run demo script. Script is using local keys from that dir.

```bash
export INJHOME="<some path there>"

./demo.sh
```

## Results

Full output looks like this:

```
1) Importing user wallet...
Wallet user1 already exists. Skipping import.
User INJ address: inj1cml96vmptgw99syqrrz8az79xer2pcgp0a885r
User ETH address: 0xC6Fe5D33615a1C52c08018c47E8Bc53646A0E101

2) Creating erc20 contract...
Contract ETH address: 0xe2F81B30E1D47DFFdBb6aB41Ec5f0572705b026d
Contract INJ address: inj1utupkv8p637llkak4dq7chc9wfc9kqndwfd8gk
Denom: erc20:0xe2F81B30E1D47DFFdBb6aB41Ec5f0572705b026d

3) Creating hook contract...
Hook ETH address: 0x17cf225bEFBdC683A48DB215305552B3897906F6
Hook INJ address: inj1zl8jykl0hhrg8fydkg2nq42jkwyhjphkkwzhzv

4) Creating namespace from unauthorized user (SHOULD FAIL)...
Error: Tx Failed. Code: 3, Log: failed to execute message; message index: 0: only denom admin authorized, sender: inj1jcltmuhplrdcwp7stlr4hlhlhgd4htqhe4c0cs, admin: inj1cml96vmptgw99syqrrz8az79xer2pcgp0a885r: unauthorized account
Failed as expected

4 bis) Creating namespace from owner of ERC20 token (SHOULD SUCCEED)...
OK

5) Minting 666...
OK

6) Querying balances through cosmos x/bank...
erc20:0xe2F81B30E1D47DFFdBb6aB41Ec5f0572705b026d: 666

7) Querying balances through EVM JSON-RPC...
erc20:0xe2F81B30E1D47DFFdBb6aB41Ec5f0572705b026d: 666

8) Transfer 55 to authorized address...
OK

9) Querying balances through cosmos x/bank...
erc20:0xe2F81B30E1D47DFFdBb6aB41Ec5f0572705b026d: 611

10) Querying balances through EVM JSON-RPC...
erc20:0xe2F81B30E1D47DFFdBb6aB41Ec5f0572705b026d: 611

11) Transfer 88 to unauthorized address...
Error: Tx Failed. Code: 3, Log: failed to execute message; message index: 0: {"tx_hash":"0x54aa8b2c1d62b3152ea880a21570edb545644fdcd65ef09e153c20799d8ef8a9","gas_used":178082,"reason":"fail to send coins in precompiled contract: EVM hook restriction: Transfer restricted: Address 0x963EBDf2e1f8DB8707D05FC75bfeFFBa1B5BaC17 is restricted from receiving: restricted action","vm_error":"execution reverted","ret":"CMN5oAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALlmYWlsIHRvIHNlbmQgY29pbnMgaW4gcHJlY29tcGlsZWQgY29udHJhY3Q6IEVWTSBob29rIHJlc3RyaWN0aW9uOiBUcmFuc2ZlciByZXN0cmljdGVkOiBBZGRyZXNzIDB4OTYzRUJEZjJlMWY4REI4NzA3RDA1RkM3NWJmZUZGQmExQjVCYUMxNyBpcyByZXN0cmljdGVkIGZyb20gcmVjZWl2aW5nOiByZXN0cmljdGVkIGFjdGlvbgAAAAAAAAA="}
```
