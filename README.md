## Upload and interact with MintBurnBankERC20 using Foundry
Install Foundry first, then:

```sh
# create address in local keystore
cast wallet import ccc --mnemonic "XXXXXXX"

# compile and deploy SC
forge create src/MintBurnBankERC20.sol:MintBurnBankERC20 -r evmixt --account ccc --broadcast --constructor-args 0xCCCC7F724FD589F95D50BeDD60E6BA1D4b145ccc "MintBurnBankERC20" "MintBurnBankERC20" 18
# copy the deployed SC address

# mint
cast send -r evmixt --account ccc 0x6139E59DceB290b5c80127dF87242429D42143d2 "mint(address,uint256)" 0xCCCC7F724FD589F95D50BeDD60E6BA1D4b145ccc 666

# query through EVM JSON-RPC
cast call -r evmixt 0x6139E59DceB290b5c80127dF87242429D42143d2 "balanceOf(address)" 0xCCCC7F724FD589F95D50BeDD60E6BA1D4b145ccc

# query through cosmos x/bank
injectived q bank balance inj1enx87uj06kyljh2shmwkpe46r493ghxv3360aq evm/0x6139E59DceB290b5c80127dF87242429D42143d2 --node https://k8s.testnet.evmix.tm.injective.network

# transfer
cast send -r evmixt --account ccc 0x6139E59DceB290b5c80127dF87242429D42143d2 "transfer(address,uint256)" 0xC6Fe5D33615a1C52c08018c47E8Bc53646A0E101 555
```