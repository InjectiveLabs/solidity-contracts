// SPDX-License-Identifier: MIT
pragma solidity >0.6.6;

import "./Staking.sol";

contract StakingTest {
    address constant stakingContract = 0x0000000000000000000000000000000000000066;
    IStakingModule staking = IStakingModule(stakingContract);

    function delegate(
        string memory validatorAddress,
        uint256 amount
    ) external returns (bool) {
        return staking.delegate(validatorAddress, amount);
    }

    function undelegate(
        string memory validatorAddress,
        uint256 amount
    ) external returns (bool) {
        return staking.undelegate(validatorAddress, amount);
    }

    function redelegate(
        string memory validatorSrc,
        string memory validatorDst,
        uint256 amount
    ) external returns (bool) {
        return staking.redelegate(validatorSrc, validatorDst, amount);
    }

    function withdrawDelegatorRewards(
        string memory validatorAddress
    ) external returns (Cosmos.Coin[] memory amount) {
        return staking.withdrawDelegatorRewards(validatorAddress);
    }

    function delegation(
        address delegatorAddress,
        string memory validatorAddress
    ) external view returns (uint256 shares, Cosmos.Coin memory balance) {
        return staking.delegation(delegatorAddress, validatorAddress);
    }
}