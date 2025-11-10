#!/bin/bash

set -e

# Listen for Transfer events and detect contracts that do not use bank precompile.
# It will print everything to stdout, only found vanilla contracts to stderr
# and append only vanilla addresses to $DUMP_FILE
# 
# To use this as a notification daemon, just redirect stderr to your notification service, example: ./bankerc20_monitor.sh 2>notif

RPC_URL=http://localhost:8545/
INTERVAL=10 #seconds
DUMP_FILE="dump.txt"

CHECKED_CONTRACTS=()

echoerr() {
	cat <<< "$@" 1>&2;
	cat <<< "$@"
}

req() { # (method, params)
	curl -s -X POST --data '{"jsonrpc":"2.0","method":"'${1}'","params":['${2}'],"id":1}' -H "Content-Type: application/json" -w "\nHTTP_STATUS:%{http_code}\n" $RPC_URL
}

check_res() {
	local exit_code=$? 
	if [ $exit_code -ne 0 ]; then
		echo "last command failed with exit code $exit_code"
		echo "URL: ${RPC_URL}"
		if [[ -n "${A}" ]]; then
			echo "full response: ${A}"
		fi
		exit $exit_code
	fi
	
	# Extract HTTP status code (last line that starts with HTTP_STATUS:)
	local http_status=$(echo "${A}" | grep "HTTP_STATUS:" | tail -1 | cut -d: -f2)
	local response_body=$(echo "${A}" | sed '/HTTP_STATUS:/d')
	
	if [[ -n "${http_status}" && "${http_status}" -ge 400 ]]; then
		echo "HTTP error: status ${http_status}"
		echo "URL: ${RPC_URL}"
		echo "full response: ${response_body}"
		exit 1
	fi
	
	# Check for JSON-RPC errors
	local error="$(echo "${response_body}" | jq -r '.error // empty' 2>/dev/null)"
	if [[ -n "${error}" && "${error}" != "null" ]]; then
		echo "JSON-RPC error: ${error}"
		echo "URL: ${RPC_URL}"
		echo "full response: ${response_body}"
		exit 1
	fi
	
	# Check if response is valid JSON
	if ! echo "${response_body}" | jq empty 2>/dev/null; then
		echo "invalid JSON response"
		echo "URL: ${RPC_URL}"
		echo "full response: ${response_body}"
		exit 1
	fi
	
	RESULT="$(echo "${response_body}" | jq '.result')"
	A="${response_body}"  # Update A to be just the body for consistency
}

decode_erc20_name() {
  local hex_with_prefix=$(echo $1 | tr -d '"')
  # Remove "0x" prefix
  local hex="${hex_with_prefix#0x}"
  # Extract string length (32 bytes after the first 32) — chars 64 to 127
  local length_hex=${hex:64:64}
  local length=$((16#${length_hex}))
  # Extract the string data (next 32 bytes = chars 128–191)
  local data_hex=${hex:128:64}
  # Trim to actual length (length * 2 hex chars)
  local data_trimmed=${data_hex:0:$((length * 2))}
  # Decode to ASCII and output
  echo "$data_trimmed" | xxd -r -p
}

echo "create filter for Transfer(address,address,uint256) event..."
A=$(req 'eth_newFilter' '{"topics":["0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"]}')
check_res
FILTER_ID=$RESULT

echo "listening for new events..."
while :
do
	A=$(req 'eth_getFilterChanges' $FILTER_ID)
	check_res
	CONTRACTS=$(echo ${RESULT} | jq '.[] | {address, transactionHash} | .[]')
	
	while IFS= read -r CONTRACT_ADDRESS; do
		if [[ "${CONTRACT_ADDRESS}" == "" ]]; then
			break
		fi

		read -r TX_HASH

		if [[ " ${CHECKED_CONTRACTS[*]} " =~ ${CONTRACT_ADDRESS} ]]; then
			continue # skip if already checked
		fi

		echo "checking $CONTRACT_ADDRESS (tx: $TX_HASH)..."

		A=$(req 'debug_traceTransaction' $TX_HASH)
		check_res
		NUM_PRECOMPILE_LOADS=$(echo "${RESULT}" | jq '[.structLogs[] | select(.op == "SLOAD") | .storage | to_entries[] | select((.value | ltrimstr("0x")) == "0000000000000000000000000000000000000000000000000000000000000064")] | length')

		if (( NUM_PRECOMPILE_LOADS == 0 )); then			
			A=$(req 'eth_call' '{"to":'$CONTRACT_ADDRESS',"data":"0x06fdde03"},"latest"')
			check_res
			TOKEN_NAME=$(decode_erc20_name $RESULT)
			A=$(req 'eth_call' '{"to":'$CONTRACT_ADDRESS',"data":"0x95d89b41"},"latest"')
			check_res
			TOKEN_SYMBOL=$(decode_erc20_name $RESULT)

			echoerr "!!! VANILLA ERC20 !!!"
			echoerr "Address: $(echo $CONTRACT_ADDRESS | tr -d '"')"
			echoerr "Token name: ${TOKEN_NAME}"
			echoerr "Token symbol: ${TOKEN_SYMBOL}"
			
			echo "$(echo $CONTRACT_ADDRESS | tr -d '"')" >> $DUMP_FILE
		fi

		CHECKED_CONTRACTS+=("$CONTRACT_ADDRESS")
	done <<< "$CONTRACTS"

	sleep $INTERVAL
done
