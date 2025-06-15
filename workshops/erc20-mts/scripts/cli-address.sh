#!/bin/sh

echo "Getting Injective address and converting to Ethereum address:"

# Get the address from keys show command
INJ_ADDRESS=$(injectived keys show $1 --keyring-backend=test -a)

# Display the Injective address
echo "\t* Injective address: $INJ_ADDRESS"

# Parse the Injective address to get the Ethereum address
ETH_ADDRESS=0x$(injectived keys parse $INJ_ADDRESS --output json | jq -r '.bytes')

# Display the Ethereum address
echo "\t* Ethereum address: $ETH_ADDRESS"

echo ""
