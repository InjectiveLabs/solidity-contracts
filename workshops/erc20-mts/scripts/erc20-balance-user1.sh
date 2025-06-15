#!/bin/sh

source .local.env

echo "Checking ERC20 balance of user1..."

USER_INJ_ADDRESS=$(injectived keys show $USER --keyring-backend=test -a)
USER_ETH_ADDRESS=0x$(injectived keys parse $USER_INJ_ADDRESS --output json | jq -r '.bytes')

# Display the addresses for verification
echo "Injective address: $USER_INJ_ADDRESS"
echo "Ethereum address: $USER_ETH_ADDRESS"

if [ -z "$ERC20_ADDRESS" ]; then
  echo "⚠️  Error: ERC20_ADDRESS env variable is not set"
  exit 1
fi

echo "\n### RUNNING ###"
echo cast call $ERC20_ADDRESS "balanceOf(address)" $USER_ETH_ADDRESS "|" xargs cast decode-abi "balanceOf(address)(uint256)"
echo "###############\n"

cast call $ERC20_ADDRESS "balanceOf(address)" $USER_ETH_ADDRESS | xargs cast decode-abi "balanceOf(address)(uint256)"

echo ""
