## Upload and interact with MintBurnBankERC20 using Foundry
Install Foundry first, then:

```sh
cast wallet import user1 --mnemonic "XXXXXXX"

forge create MintBurnBankERC20.sol:MintBurnBankERC20 -r evmixt --account user1
```