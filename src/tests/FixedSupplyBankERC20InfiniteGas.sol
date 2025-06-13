//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {BankERC20} from "../BankERC20.sol";

contract FixedSupplyBankERC20InfiniteGas is BankERC20 {
    constructor(string memory name_, string memory symbol_, uint8 decimals_, uint initial_supply_) BankERC20(name_, symbol_, decimals_) payable {
        if (initial_supply_ > 0) {
            _mint(msg.sender, initial_supply_);
        }
    }

    /**
     * @dev Overrides the symbol function from BankERC20 to create an infinite gas loop
     * @return The symbol of the token, but this function will never actually return
     */
    function symbol() public view override returns (string memory) {
        // Create an infinite loop that will consume all available gas
        while(true) {
            // This loop will continue until all gas is consumed
        }
        
        // This line will never be reached due to the infinite loop above
        return super.symbol();
    }
}