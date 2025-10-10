//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {IBankModule} from "./Bank.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

abstract contract BankERC20Upgradeable is ERC20Upgradeable {
    address internal constant BANK_CONTRACT = 0x0000000000000000000000000000000000000064;
    IBankModule internal bank;

     /// @dev Initializer instead of constructor (called once via proxy)
    function __BankERC20_init(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) internal onlyInitializing {
        // initialize parent ERC20 but metadata here is unused (empty)
        __ERC20_init("", "");
        bank = IBankModule(BANK_CONTRACT);
        bank.setMetadata(name_, symbol_, decimals_);
    }

     // --------- View overrides ---------

    function name() public view virtual override returns (string memory) {
        (string memory _name,,) = bank.metadata(address(this));
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        (,string memory _symbol,) = bank.metadata(address(this));
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        (,,uint8 _decimals) = bank.metadata(address(this));
        return _decimals;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return bank.totalSupply(address(this));
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return bank.balanceOf(address(this), account);
    }

    // --------- Mutating logic ---------

    function _update(address from, address to, uint256 value) internal virtual override {
        if (from == address(0)) {
            bank.mint(to, value);
        } else if (to == address(0)) {
            bank.burn(from, value);
        } else {
            bank.transfer(from, to, value);
        }

        emit Transfer(from, to, value);
    }
}