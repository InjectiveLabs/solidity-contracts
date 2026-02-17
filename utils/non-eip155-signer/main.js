#!/usr/bin/env node

const { keccak256, ecsign, toBuffer, bufferToHex } = require('ethereumjs-util');
const rlp = require('rlp');

let data = process.argv[2] ? (process.argv[2].startsWith('0x') ? process.argv[2] : '0x' + process.argv[2]) : '';
if (data.length === 0) {
  console.error('No hex-encoded calldata provided. Usage: node main.js <calldata>');
  process.exit(1);
} else if (!process.env.ETH_PRIVATE_KEY) {
  console.error('ETH_PRIVATE_KEY environment variable is not set');
  process.exit(1);
}

const txParams = {
  nonce: '0x00',
  gasPrice: '0x9896800', // 160000000 in hex
  gasLimit: '0x1e8480', // 2000000 in hex
  value: '0xde0b6b3a7640000', // 10^18 in hex (1 INJ)
  data: data,
};

const privateKey = toBuffer(process.env.ETH_PRIVATE_KEY.startsWith('0x') ? process.env.ETH_PRIVATE_KEY : '0x' + process.env.ETH_PRIVATE_KEY);

// Prepare the transaction fields for RLP encoding
// For nonce 0, use empty buffer to avoid leading zero issue
const txData = [
  txParams.nonce === '0x00' ? Buffer.alloc(0) : toBuffer(txParams.nonce), // Empty buffer for nonce 0
  toBuffer(txParams.gasPrice),
  toBuffer(txParams.gasLimit),
  Buffer.alloc(0), // Empty buffer for contract deployment
  toBuffer(txParams.value),
  toBuffer(txParams.data)
];

// RLP encode the transaction data
const rlpEncoded = rlp.encode(txData);

// Hash the RLP encoded transaction data
const msgHash = keccak256(toBuffer(rlpEncoded));

// Sign the hash
const signature = ecsign(msgHash, privateKey);

// Append signature to the transaction data
const rawTx = txData.concat([
  toBuffer(signature.v),
  toBuffer(signature.r),
  toBuffer(signature.s)
]);

// RLP encode the signed transaction
const serializedTx = rlp.encode(rawTx);

console.log('Signed Transaction:', bufferToHex(serializedTx));

// Calculate and print the transaction hash
const txHash = keccak256(toBuffer(serializedTx));
console.log('Transaction Hash:', bufferToHex(txHash));
