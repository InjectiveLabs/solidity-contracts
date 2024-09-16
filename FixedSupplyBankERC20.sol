//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {BankERC20} from "./BankERC20.sol";

contract FixedSupplyBankERC20 is BankERC20 {
     
     uint constant _initial_supply = 100 * (10**18); // CHANGE THIS TO YOUR DESIRED INITIAL SUPPLY

    constructor(string memory name_, string memory symbol_, uint8 decimals_) BankERC20(name_, symbol_, decimals_) {
        _mint(msg.sender, _initial_supply);
    }
}