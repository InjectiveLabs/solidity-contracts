#!/bin/sh

cast wallet import $USER \
    --unsafe-password "$USER_PWD" \
    --mnemonic "$USER_MNEMONIC"