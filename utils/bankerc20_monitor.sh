# listen for Transfer events and detect contracts that do not use bank precompile

RPC_URL=https://k8s.testnet.evmix.json-rpc.injective.network
INTERVAL=1 #seconds

CHECKED_CONTRACTS=()
VANILLA_CONTRACTS=()

echoerr() { cat <<< "$@" 1>&2; }

req() { # (method, params)
	curl -s -X POST --data '{"jsonrpc":"2.0","method":"'${1}'","params":['${2}'],"id":1}' -H "Content-Type: application/json" $RPC_URL
}

check_res() {
	local error="$(echo "${A}" | jq '.error')"
	local res="$(echo "${A}" | jq '.result')"
	if [[ "${error}" != "null" ]]; then
		echo "last command ended with error: ${error}"
    else
    	echo ${res}
	fi
	A=""
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
FILTER_ID=$(check_res)

echo "listening for new events..."
while :
do
	A=$(req 'eth_getFilterChanges' $FILTER_ID)
	CONTRACTS=$(check_res | jq '.[] | {address, transactionHash} | .[]')
	
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
		NUM_PRECOMPILE_LOADS=$(check_res | jq '.structLogs.[] | select(.op == "SLOAD").storage | to_entries.[] | select(.value == "0000000000000000000000000000000000000000000000000000000000000064") | length')

		if [[ "${NUM_PRECOMPILE_LOADS}" == "" ]]; then			
			A=$(req 'eth_call' '{"to":'$CONTRACT_ADDRESS',"data":"0x06fdde03"},"latest"')
			RESPONSE=$(check_res)
			TOKEN_NAME=$(decode_erc20_name $RESPONSE)
			A=$(req 'eth_call' '{"to":'$CONTRACT_ADDRESS',"data":"0x95d89b41"},"latest"')
			RESPONSE=$(check_res)
			TOKEN_SYMBOL=$(decode_erc20_name $RESPONSE)

			echo $'\n!!! VANILLA ERC20 !!!'
			echo "Address: $(echo $CONTRACT_ADDRESS | tr -d '"')"
			echo "Token name: ${TOKEN_NAME}"
			echo $'Token symbol: '${TOKEN_SYMBOL}'\n\n'
			VANILLA_CONTRACTS+=$CONTRACT_ADDRESS

			echoerr "All vanilla contracts"
			echoerr $VANILLA_CONTRACTS
			echoerr $'\n'
		fi

		CHECKED_CONTRACTS+=$CONTRACT_ADDRESS
	done <<< "$CONTRACTS"

	sleep $INTERVAL
done

# all logs:
# curl -X POST --data '{"jsonrpc":"2.0","method":"eth_getFilterLogs","params":["'${FILTER_ID}'"],"id":1}' -H "Content-Type: application/json" https://k8s.testnet.evmix.json-rpc.injective.network | jq

# only new logs:
# curl -X POST --data '{"jsonrpc":"2.0","method":"eth_getFilterChanges","params":["'${FILTER_ID}'"],"id":1}' -H "Content-Type: application/json" https://k8s.testnet.evmix.json-rpc.injective.network | jq

2. if contract address is not checked yet, trace each tx for opcodes and look for JUMPI on 0x64

 curl -s -X POST --data '{"jsonrpc":"2.0","method":"debug_traceTransaction","params":["0x6207ee5f5bf49ce737c7f4432cb33786d89a3adf2951b9f66a45d43e59793227", {}],"id":1}' -H "Content-Type: application/json" https://k8s.testnet.evmix.json-rpc.injective.network | jq '.result.structLogs.[] | select(.op == "SLOAD").storage | to_entries.[] | select(.value == "0000000000000000000000000000000000000000000000000000000000000064")'
