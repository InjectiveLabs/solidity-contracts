# Local Chain for the Demos

`start.sh` runs a single-node Injective chain in Docker from the public
[`injectivelabs/injective-core`](https://hub.docker.com/r/injectivelabs/injective-core)
image. The [erc20](../erc20), [exchange-direct](../exchange-direct),
[exchange-proxy](../exchange-proxy), [permissions-hook](../permissions-hook),
[staking](../staking) and [winj9](../winj9) demos run against it. The
[swap demo](../swap) starts its own chain and does not need it.

## Requirements

- Docker. The image is published for `linux/amd64` and `linux/arm64`:

  ```
  docker pull injectivelabs/injective-core:v1.21.0
  ```

- `jq` and `curl`.

## Start and stop

From the repo root:

```
./demos/localnet/start.sh
export PATH="$(pwd)/demos/localnet/bin:$PATH"
```

The second line puts a `bin/injectived` wrapper on the `PATH`. The demos call
`injectived` for keys, queries and some transactions, and the wrapper runs
those commands inside the node's container.

If you have your own `injectived` v1.21.0 or later, you can skip the wrapper.
Linux x86-64 builds are on the
[releases page](https://github.com/InjectiveFoundation/injective-core/releases):
put `injectived` on your `PATH` and `libwasmvm.x86_64.so` on the library path
(e.g. `/usr/lib`, or `LD_LIBRARY_PATH`).

To stop the chain:

```
./demos/localnet/stop.sh
```

The next `start.sh` wipes the chain and starts a fresh one.

## What it sets up

| | |
|---|---|
| Chain ID | `injective-1` |
| EVM JSON-RPC | `http://localhost:8545` |
| Tendermint RPC | `http://localhost:26657` |
| gRPC | `localhost:9900` |
| REST | `http://localhost:10337` |
| Chain home | `.injectived` in the repo root (`file` keyring, passphrase `12345678`) |
| Node log | `.injectived/node.log` |

- **Keys:** `user1` (the test mnemonic in the demos' `.local.env` files) and
  `user2`. Each holds 1,000,000 INJ and 100,000,000 USDT
  (`peggy0xdAC17F958D2ee523a2206206994597C13D831ec7`, 6 decimals). These are
  test keys only; never send real funds to them.
- **Market:** `INJ/USDT PERP`, market ID
  `0x6a80b56ecb522b340d88668b5383a60655ef64a6d37167dc509cf485bb2c141d`. It is
  priced by a `local` provider oracle that `user1` relays, starting at
  1.461 USDT, and has a 10,000 USDT insurance fund.
- `user1` is an exchange admin, and instant derivative market launches are
  enabled.

| Variable | Default | Purpose |
|---|---|---|
| `INJECTIVED_IMAGE` | `injectivelabs/injective-core:v1.21.0` | Docker image |
| `INJHOME` | `<repo>/.injectived` | Chain home. `start.sh` only wipes a home it created |
| `LOCALNET_CONTAINER` | `injective-localnet` | Container name, also used by `bin/injectived` and `stop.sh` |

The node needs ports 26657, 8545, 8546, 9900 and 10337 to be free. Docker
publishes them on `127.0.0.1` only.
