//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {BankERC20} from "./BankERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MintBurnBankERC20 is Ownable, BankERC20 {

    constructor(address initialOwner, string memory name_, string memory symbol_, uint8 decimals_)
        BankERC20(name_, symbol_, decimals_)
        Ownable(initialOwner)
    {}

    function mint(address to, uint256 amount) public virtual onlyOwner {
        _mint(to, amount);
    }

    function burn(uint256 value) public virtual {
        _burn(_msgSender(), value);
    }

    function burnFrom(address account, uint256 value) public virtual {
        _spendAllowance(account, _msgSender(), value);
        _burn(account, value);
    }
}
