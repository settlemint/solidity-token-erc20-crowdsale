# Makefile for Foundry Ethereum Development Toolkit

.PHONY: build test format snapshot anvil deploy-btp deploy-anvil cast help subgraph clear-anvil-port

build:
	@echo "Building with Forge..."
	@forge build

test:
	@echo "Testing with Forge..."
	@forge test

format:
	@echo "Formatting with Forge..."
	@forge fmt

snapshot:
	@echo "Creating gas snapshot with Forge..."
	@forge snapshot

anvil:
	@echo "Starting Anvil local Ethereum node..."
	@make clear-anvil-port
	@anvil

deploy-anvil:
	@echo "Deploying with Forge to Anvil..."
	@timestamp=$$(date +"%s") && \
	forge create ./src/ExampleToken.sol:ExampleToken --rpc-url anvil --interactive --constructor-args "ExampleToken" "ET" "3500000" "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" |  sed 's/Deployed to:/Deployed ExampleToken to:/' | tee deployment-anvil.txt && \
	forge create ./src/ExampleVestingWallet.sol:ExampleVestingWallet --rpc-url anvil --interactive --constructor-args "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" $$timestamp "31536000" |  sed 's/Deployed to:/Deployed ExampleVestingWallet to:/' | tee -a deployment-anvil.txt && \
	forge create ./src/ExampleVestingVault.sol:ExampleVestingVault --rpc-url anvil --interactive --constructor-args "$$(grep "Deployed ExampleToken to:" deployment-anvil.txt | awk '{print $$4}')" |  sed 's/Deployed to:/Deployed ExampleVestingVault to:/' | tee -a deployment-anvil.txt && \
	forge create ./src/ExampleCrowdSale.sol:ExampleCrowdSale --rpc-url anvil --interactive --constructor-args "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" "$$(grep "Deployed ExampleToken to:" deployment-anvil.txt | awk '{print $$4}')" "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" "250" $$timestamp "$$(grep "Deployed ExampleVestingVault to:" deployment-anvil.txt | awk '{print $$4}')" |  sed 's/Deployed to:/Deployed ExampleCrowdSale to:/' | tee -a deployment-anvil.txt


deploy-btp:
	@eval $$(curl -H "x-auth-token: $${BTP_SERVICE_TOKEN}" -s $${BTP_CLUSTER_MANAGER_URL}/ide/foundry/$${BTP_SCS_ID}/env | sed 's/^/export /'); \
	args=""; \
	if [ ! -z "$${BTP_FROM}" ]; then \
		args="--unlocked --from $${BTP_FROM}"; \
	else \
		echo "\033[1;33mWARNING: No keys are activated on the node, falling back to interactive mode...\033[0m"; \
		echo ""; \
		args="--interactive"; \
	fi; \
	if [ ! -z "$${BTP_GAS_PRICE}" ]; then \
		args="$$args --gas-price $${BTP_GAS_PRICE}"; \
	fi; \
	if [ "$${BTP_EIP_1559_ENABLED}" = "false" ]; then \
		args="$$args --legacy"; \
	fi; \
	timestamp=$$(date +"%s") && \
	forge create ./src/ExampleToken.sol:ExampleToken $${EXTRA_ARGS} --rpc-url $${BTP_RPC_URL} $$args --constructor-args "ExampleToken" "ET" "3500000" "$${BTP_FROM}" |  sed 's/Deployed to:/Deployed ExampleToken to:/' | sed 's/Transaction hash:/ExampleToken Transaction hash:/' | tee deployment-btp.txt && \
	forge create ./src/ExampleVestingWallet.sol:ExampleVestingWallet $${EXTRA_ARGS} --rpc-url $${BTP_RPC_URL} $$args --constructor-args "$${BTP_FROM}" $$timestamp "31536000" |  sed 's/Deployed to:/Deployed ExampleVestingWallet to:/' | sed 's/Transaction hash:/ExampleVestingWallet Transaction hash:/' | tee -a deployment-btp.txt && \
	forge create ./src/ExampleVestingVault.sol:ExampleVestingVault $${EXTRA_ARGS} --rpc-url $${BTP_RPC_URL} $$args --constructor-args "$$(grep "Deployed ExampleToken to:" deployment-btp.txt | awk '{print $$4}')" |  sed 's/Deployed to:/Deployed ExampleVestingVault to:/' |  sed 's/Transaction hash:/ExampleVestingVault Transaction hash:/' | tee -a deployment-btp.txt && \
	forge create ./src/ExampleCrowdSale.sol:ExampleCrowdSale $${EXTRA_ARGS} --rpc-url $${BTP_RPC_URL} $$args --constructor-args "$${BTP_FROM}" "$$(grep "Deployed ExampleToken to:" deployment-btp.txt | awk '{print $$4}')" "$${BTP_FROM}" "250" $$timestamp "$$(grep "Deployed ExampleVestingVault to:" deployment-btp.txt | awk '{print $$4}')" |  sed 's/Deployed to:/Deployed ExampleCrowdSale to:/' |  sed 's/Transaction hash:/ExampleCrowdSale Transaction hash:/' | tee -a deployment-btp.txt


cast:
	@echo "Interacting with EVM via Cast..."
	@cast $(SUBCOMMAND)


subgraph:
	@echo "Deploying the subgraph..."
	@rm -Rf subgraph/subgraph.config.json
	@TOKEN_ADDRESS=$$(grep "Deployed ExampleToken to:" deployment-btp.txt | awk '{print $$4}'); \
	VESTING_WALLET_ADDRESS=$$(grep "Deployed ExampleVestingWallet to:" deployment-btp.txt | awk '{print $$4}'); \
	VESTING_VAULT_ADDRESS=$$(grep "Deployed ExampleVestingVault to:" deployment-btp.txt | awk '{print $$4}'); \
	CROWDSALE_ADDRESS=$$(grep "Deployed ExampleCrowdSale to:" deployment-btp.txt | awk '{print $$4}'); \
	TRANSACTION_HASH_TOKEN=$$(grep "ExampleToken Transaction hash:" deployment-btp.txt | awk '{print $$4}'); \
	BLOCK_NUMBER_TOKEN=$$(cast receipt --rpc-url btp $${TRANSACTION_HASH_TOKEN} | grep "blockNumber" | awk '{print $$2}' | sed '2d'); \
	TRANSACTION_HASH_WALLET=$$(grep "ExampleVestingWallet Transaction hash:" deployment-btp.txt | awk '{print $$4}'); \
	BLOCK_NUMBER_WALLET=$$(cast receipt --rpc-url btp $${TRANSACTION_HASH_WALLET} | grep "blockNumber" | awk '{print $$2}' | sed '2d'); \
	TRANSACTION_HASH_VAULT=$$(grep "ExampleVestingVault Transaction hash:" deployment-btp.txt | awk '{print $$4}'); \
	BLOCK_NUMBER_VAULT=$$(cast receipt --rpc-url btp $${TRANSACTION_HASH_VAULT} | grep "blockNumber" | awk '{print $$2}' | sed '2d'); \
	TRANSACTION_HASH_CROWDSALE=$$(grep "ExampleCrowdSale Transaction hash:" deployment-btp.txt | awk '{print $$4}'); \
	BLOCK_NUMBER_CROWDSALE=$$(cast receipt --rpc-url btp $${TRANSACTION_HASH_CROWDSALE} | grep "blockNumber" | awk '{print $$2}' | sed '2d'); \
	export TOKEN_ADDRESS=$$TOKEN_ADDRESS; \
	export VESTING_WALLET_ADDRESS=$$VESTING_WALLET_ADDRESS; \
	export VESTING_VAULT_ADDRESS=$$VESTING_VAULT_ADDRESS; \
	export CROWDSALE_ADDRESS=$$CROWDSALE_ADDRESS; \
	export BLOCK_NUMBER_TOKEN=$$BLOCK_NUMBER_TOKEN; \
	export BLOCK_NUMBER_WALLET=$$BLOCK_NUMBER_WALLET; \
	export BLOCK_NUMBER_VAULT=$$BLOCK_NUMBER_VAULT; \
	export BLOCK_NUMBER_CROWDSALE=$$BLOCK_NUMBER_CROWDSALE; \
	yq e -p=json -o=json '.datasources[0].address = env(TOKEN_ADDRESS) | .datasources[1].address = env(CROWDSALE_ADDRESS) | .datasources[2].address = env(VESTING_VAULT_ADDRESS) | .datasources[3].address = env(VESTING_WALLET_ADDRESS) | .datasources[0].startBlock = env(BLOCK_NUMBER_TOKEN) | .datasources[1].startBlock = env(BLOCK_NUMBER_CROWDSALE) | .datasources[2].startBlock = env(BLOCK_NUMBER_VAULT) | .datasources[3].startBlock = env(BLOCK_NUMBER_WALLET) | .chain = env(BTP_NODE_UNIQUE_NAME)' subgraph/subgraph.config.template.json > subgraph/subgraph.config.json
	@cd subgraph && npx graph-compiler --config subgraph.config.json --include node_modules/@openzeppelin/subgraphs/src/datasources ./datasources --export-schema --export-subgraph
	@cd subgraph && yq e '.specVersion = "0.0.4"' -i generated/solidity-token-erc20-crowdsale.subgraph.yaml
	@cd subgraph && yq e '.description = "Solidity Token ERC20 CrowdSale"' -i generated/solidity-token-erc20-crowdsale.subgraph.yaml
	@cd subgraph && yq e '.repository = "https://github.com/settlemint/solidity-token-erc20-crowdsale"' -i generated/solidity-token-erc20-crowdsale.subgraph.yaml
	@cd subgraph && yq e '.features = ["nonFatalErrors", "fullTextSearch", "ipfsOnEthereumContracts"]' -i generated/solidity-token-erc20-crowdsale.subgraph.yaml
	@cd subgraph && npx graph codegen generated/solidity-token-erc20-crowdsale.subgraph.yaml
	@cd subgraph && npx graph build generated/solidity-token-erc20-crowdsale.subgraph.yaml
	@eval $$(curl -H "x-auth-token: $${BTP_SERVICE_TOKEN}" -s $${BTP_CLUSTER_MANAGER_URL}/ide/foundry/$${BTP_SCS_ID}/env | sed 's/^/export /'); \
	if [ -z "$${BTP_MIDDLEWARE}" ]; then \
		echo "\033[1;31mERROR: You have not launched a graph middleware for this smart contract set, aborting...\033[0m"; \
		exit 1; \
	else \
		cd subgraph; \
		npx graph create --node $${BTP_MIDDLEWARE} $${BTP_SCS_NAME}; \
		npx graph deploy --version-label v1.0.$$(date +%s) --node $${BTP_MIDDLEWARE} --ipfs $${BTP_IPFS}/api/v0 $${BTP_SCS_NAME} generated/solidity-token-erc20-crowdsale.subgraph.yaml; \
	fi

help:
	@echo "Forge help..."
	@forge --help
	@echo "Anvil help..."
	@anvil --help
	@echo "Cast help..."
	@cast --help

clear-anvil-port:
	-fuser -k -n tcp 8545