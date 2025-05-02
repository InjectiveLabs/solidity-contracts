pragma solidity 0.6.12;

import {IBankModule} from "./Bank.sol";
import { FiatTokenV2_2 } from "./FiatTokenV2_2.sol";

// solhint-disable func-name-mixedcase

/**
 * @title FiatToken V2.Inj
 * @notice ERC20 Token backed by Injective bank precompile, based on version 2.2 
 */
contract FiatTokenV2_Inj is FiatTokenV2_2 {

    address constant bankPrecompile = 0x0000000000000000000000000000000000000064;
    IBankModule bank = IBankModule(bankPrecompile);

    /**
     * @notice Initialize v2.Inj
     */
    function initializeV2_Inj() external {
        // solhint-disable-next-line reason-string
        require(_initializedVersion == 3);

        bank.setMetadata(name, symbol, decimals);

        _initializedVersion = 4;
    }

    /* 1. in FiatTokenV1 change the signature of mint() to: (rename to _mint and replace external with internal modifier)
    function _mint(address _to, uint256 _amount)
        internal
        whenNotPaused
        onlyMinters
        notBlacklisted(msg.sender)
        notBlacklisted(_to)
        returns (bool)
    */
    function mint(address _to, uint256 _amount)
        external
        returns (bool)
    {
        bank.mint(_to, _amount);
        return super._mint(_to, _amount); // cal FiatTokenV1.mint()
    }

    /* 2. in FiatTokenV1 change the signature of burn() to: (rename to _burn and replace external with internal modifier)
    function _burn(uint256 _amount)
        internal
        whenNotPaused
        onlyMinters
        notBlacklisted(msg.sender)
    */
    function burn(uint256 _amount)
        external
    {
        bank.burn(msg.sender, _amount);
        super._burn(_amount); // cal FiatTokenV1.burn()
    }

    /* 3. in FiatTokenV1 change the signature of _transfer() to: (add virtual modifier)
    function _transfer(
        address from,
        address to,
        uint256 value
    ) virtual internal override
    */
    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal override returns (bool) {
        bank.transfer(from, to, value);
        return super._transfer(from, to, value);
    }

}