# Bank Precompile Tests

This directory contains tests for the Injective Bank precompile implementation in Foundry.

## BankPrecompile.t.sol

Comprehensive integration test for the Bank precompile at address `0x64`.

### Prerequisites

**This test requires the Injective Foundry fork.** You must build and install Foundry from:
```
https://github.com/InjectiveLabs/foundry/tree/CP-698/complete-bank-precompile
```

To build and install:
```bash
git clone https://github.com/InjectiveLabs/foundry.git
cd foundry
git checkout CP-698/complete-bank-precompile
cargo build --release --target aarch64-apple-darwin
cp target/aarch64-apple-darwin/release/forge ~/.foundry/bin/forge
```

The standard Foundry release does **not** include the Bank precompile implementation.

### Running the Test

```bash
forge script test/BankPrecompile.t.sol:BankPrecompileTest --chain-id 1776
```

**Important**: Use `forge script` with `--chain-id 1776` instead of `forge test`. The chain ID activates Injective network features and properly injects the precompile. The standard `forge test` command doesn't inject precompiles even with the chain-id flag.

### Test Scenario

The test runs a comprehensive story exercising all 7 precompile methods:

1. **Setup** - Set token metadata ("Test Token", "TEST", 18 decimals)
2. **Mint** - Mint 10,000 tokens to Alice and 5,000 to Bob
3. **Transfer** - Alice transfers 3,000 tokens to Charlie
4. **Burn** - Burn 2,000 tokens from Bob
5. **Transfer** - Bob transfers 1,000 tokens to Alice
6. **Verify** - Final state: Alice=8,000, Bob=2,000, Charlie=3,000, Total=13,000

### Expected Output

```
=== Injective Bank Precompile Integration Test ===

1. Setting up token metadata...
   Token created: Test Token (TEST) with 18 decimals

2. Checking initial balances (should be zero)...
   All balances start at zero [OK]

3. Minting 10,000 tokens to Alice...
   Alice balance: 10000
   Total supply: 10000

4. Minting 5,000 tokens to Bob...
   Bob balance: 5000
   Total supply: 15000

5. Alice transfers 3,000 tokens to Charlie...
   Alice balance: 7000
   Charlie balance: 3000
   Total supply: 15000 (unchanged)

6. Burning 2,000 tokens from Bob...
   Bob balance: 3000
   Total supply: 13000

7. Bob transfers 1,000 tokens to Alice...
   Alice balance: 8000
   Bob balance: 2000

8. Final state summary:
   ========================
   Alice:   8000 tokens
   Bob:     2000 tokens
   Charlie: 3000 tokens
   ========================
   Total:   13000 tokens

=== All operations completed successfully! ===
```