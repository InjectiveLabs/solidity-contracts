#!/bin/sh

source .local.env

echo "Importing user wallet to Injective CLI"

if injectived keys list --keyring-backend=test | grep -q $USER; then
    echo "Wallet $USER already exists. Skipping import."
else
    echo "$USER_MNEMONIC" | injectived keys add $USER --recover --keyring-backend=test
fi

echo ""

echo "Getting Injective address and converting to Ethereum address:"

# Get the address from keys show command
INJ_ADDRESS=$(injectived keys show $USER --keyring-backend=test -a)

# Display the Injective address
echo "\t* Injective address: $INJ_ADDRESS"

# Parse the Injective address to get the Ethereum address
ETH_ADDRESS=0x$(injectived keys parse $INJ_ADDRESS --output json | jq -r '.bytes')

# Display the Ethereum address
echo "\t* Ethereum address: $ETH_ADDRESS"

echo ""
