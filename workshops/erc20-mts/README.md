## ERC20 Demo

This demo shows MTS (Multi-VM Token Standard) and how to use it to create a token that is representable in multiple VMs.

### Prerequisites

- [Injective CLI](https://docs.injective.network/docs/getting-started/cli)
- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Running the demo

1. Create a new ERC20 token
2. Mint tokens to a user
3. Check balances via CLI
4. Check balances via Foundry cast
5. Interact with WASM contract
6. Query WASM contract state

### Conclusion

We've created an ERC20 tokens that is represented at the same address in both the EVM and WASM VMs, also native state.
