#!/bin/sh

set -e

forge build

export BYTECODE=$(forge inspect src/WINJ9.sol:WINJ9 bytecode)
export ENCODED_ARGS=$(cast abi-encode "constructor(string,string,uint8)" "Wrapped INJ" "WINJ" 18)

pushd utils/non-eip155-signer
npm install
popd

npx ./utils/non-eip155-signer $BYTECODE${ENCODED_ARGS:2}
