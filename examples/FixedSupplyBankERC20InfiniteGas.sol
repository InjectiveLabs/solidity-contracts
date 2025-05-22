//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {FixedSupplyBankERC20} from "../src/FixedSupplyBankERC20.sol";

contract FixedSupplyBankERC20InfiniteGas is FixedSupplyBankERC20 {
    constructor(string memory name_, string memory symbol_, uint8 decimals_, uint initial_supply_) FixedSupplyBankERC20(name_, symbol_, decimals_, initial_supply_) {}

    function symbol() public view override returns (string memory) {
         while (true) {
            // do nothing
        }
        
        string memory _symbol;
        (, _symbol,) = bank.metadata(address(this));
        return _symbol;
    }
}