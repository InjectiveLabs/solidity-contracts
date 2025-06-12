all:

add-keys:
	./scripts/import-cli-key.sh
	./scripts/import-cast-key.sh

deploy-erc20:
	./scripts/deploy-erc20.sh

balance1-cast:
	./scripts/erc20-balance-user1.sh

balance1-cli:
	./scripts/cli-balances-user1.sh

deploy-wasm:
	./scripts/deploy-wasm.sh

.PHONY: all add-keys deploy-erc20 balance1-cast balance1-cli deploy-wasm
