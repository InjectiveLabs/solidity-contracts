//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import {BankERC20Upgradeable} from "./BankERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract MintBurnBankERC20Upgradeable is
    OwnableUpgradeable,
    BankERC20Upgradeable
{
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address initialOwner,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) external payable initializer {
        __BankERC20_init(name_, symbol_, decimals_);
        __Ownable_init(initialOwner);
    }

    function mint(address to, uint256 amount) public payable virtual onlyOwner {
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
