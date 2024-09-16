//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {BankERC20} from "./BankERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MintBurnBankERC20 is ERC20Burnable, Ownable, BankERC20 {

    constructor(address initialOwner, string memory name_, string memory symbol_, uint8 decimals_)
        BankERC20(name_, symbol_, decimals_)
        Ownable(initialOwner)
    {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}