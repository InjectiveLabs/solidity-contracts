#!/bin/sh

source .local.env

echo "Checking ERC20 balance of user2..."

if [ -z "$ERC20_ADDRESS" ]; then
  echo "⚠️  Error: ERC20_ADDRESS env variable is not set"
  exit 1
fi

echo "\n### RUNNING ###"
echo cast call $ERC20_ADDRESS "balanceOf(address)" $1 "|" xargs cast decode-abi "balanceOf(address)(uint256)"
echo "###############\n"

cast call $ERC20_ADDRESS "balanceOf(address)" $1 | xargs cast decode-abi "balanceOf(address)(uint256)"

echo ""
