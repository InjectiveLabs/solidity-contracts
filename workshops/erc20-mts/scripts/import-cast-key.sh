#!/bin/sh

source .local.env

echo "Importing user wallet to Cast"

if cast wallet list | grep -q $USER; then
    echo "Wallet $USER already exists. Skipping import."
else
    cast wallet import $USER \
        --unsafe-password "$USER_PWD" \
        --mnemonic "$USER_MNEMONIC"
fi

echo ""
