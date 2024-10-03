//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {BankERC20} from "./BankERC20.sol";

contract FixedSupplyBankERC20 is BankERC20 {
    constructor(string memory name_, string memory symbol_, uint8 decimals_, uint initial_supply_) BankERC20(name_, symbol_, decimals_) {
        if (initial_supply_ > 0) {
            _mint(msg.sender, initial_supply_);
        }
    }
}