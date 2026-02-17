
# Staking Precompile Documentation

The Staking Precompile allows smart contracts and externally owned accounts to interact with the staking module of the chain. This includes delegating tokens to validators, undelegating them, redelegating to another validator, querying delegation data, and withdrawing staking rewards.

It is available at the fixed address `0x0000000000000000000000000000000000000066`

## Interface

```solidity
interface IStakingModule {
    function delegate(string memory validatorAddress, uint256 amount) external returns (bool success);
    function undelegate(string memory validatorAddress, uint256 amount) external returns (bool success);
    function redelegate(string memory validatorSrcAddress, string memory validatorDstAddress, uint256 amount) external returns (bool success);
    function delegation(address delegatorAddress, string memory validatorAddress) external view returns (uint256 shares, Cosmos.Coin calldata balance);
    function withdrawDelegatorRewards(string memory validatorAddress) external returns (Cosmos.Coin[] calldata amount);
}
```

## Methods

### `delegate`

Delegates tokens from the caller to the specified validator.

```solidity
function delegate(string memory validatorAddress, uint256 amount) external returns (bool success);
```

**Parameters**
- `validatorAddress`: The Bech32-encoded address of the validator.
- `amount`: The number of tokens to delegate, using the bond denomination precision.

**Returns**
- `success`: Boolean indicating whether the operation succeeded.

**Example**
```solidity
stakingModule.delegate("injvaloper1...", 100_000_000);
```

### `undelegate`

Initiates undelegation of tokens from a validator.

```solidity
function undelegate(string memory validatorAddress, uint256 amount) external returns (bool success);
```

**Parameters**
- `validatorAddress`: The Bech32-encoded address of the validator.
- `amount`: Amount of tokens to undelegate.

**Returns**
- `success`: Boolean indicating whether the operation succeeded.

**Example**
```solidity
stakingModule.undelegate("injvaloper1...", 50_000_000);
```

### `redelegate`

Redelegates tokens from one validator to another.

```solidity
function redelegate(string memory validatorSrcAddress, string memory validatorDstAddress, uint256 amount) external returns (bool success);
```

**Parameters**
- `validatorSrcAddress`: Source validator's Bech32-encoded address.
- `validatorDstAddress`: Destination validator's Bech32-encoded address.
- `amount`: Amount of tokens to redelegate.

**Returns**
- `success`: Boolean indicating whether the redelegation succeeded.

**Example**
```solidity
stakingModule.redelegate("injvaloper1src...", "injvaloper1dst...", 20_000_000);
```

### `delegation`

Queries the delegation state between a delegator and a validator.

```solidity
function delegation(address delegatorAddress, string memory validatorAddress) external view returns (uint256 shares, Cosmos.Coin calldata balance);
```

**Parameters**
- `delegatorAddress`: The EVM address of the delegator.
- `validatorAddress`: Bech32-encoded address of the validator.

**Returns**
- `shares`: Amount of staking shares owned by the delegator.
- `balance`: Amount of tokens delegated (in bond denom precision).

**Example**
```solidity
(uint256 shares, Cosmos.Coin memory balance) = stakingModule.delegation(msg.sender, "injvaloper1...");
```

### `withdrawDelegatorRewards`

Withdraws accumulated staking rewards from a validator.

```solidity
function withdrawDelegatorRewards(string memory validatorAddress) external returns (Cosmos.Coin[] calldata amount);
```

**Parameters**
- `validatorAddress`: Bech32-encoded address of the validator.

**Returns**
- `amount`: Array of Coin objects representing withdrawn rewards.

**Example**
```solidity
Cosmos.Coin[] memory rewards = stakingModule.withdrawDelegatorRewards("injvaloper1...");
```

## Notes

- All `amount` parameters must respect the bond denomination’s decimal precision (usually 6 or 18 decimals depending on the chain).
- The Bech32-encoded validator address must be correctly formatted and valid on the host chain.
- Rewards and balances are returned as `Cosmos.Coin` objects, which typically contain `{string denom, uint256 amount}`.

## Demo

Please refer to the [demo](../demos/staking/README.md) to see how to build, deploy, and interact with a smart-contract that calls the Staking Precompile.
