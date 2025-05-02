#!/bin/sh

forge verify-contract \
  -r $NODE \
  --verifier blockscout \
  --verifier-url 'https://k8s.testnet.evm.blockscout.api.injective.network/api/' \
  $ADDR \
  src/ExchangeTest.sol:ExchangeTest