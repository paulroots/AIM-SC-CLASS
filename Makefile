# Smart Contracts Lab. Run `make` to see this list.

NETWORK  ?= local
CONTRACT ?= Counter
NAME     ?=
STEP     ?=
ARG      ?=

.PHONY: help install doctor anvil build test deploy verify dapp new-dapp did fund-students sync-design zip clean

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage: make <target> [NETWORK=local|prismo] [CONTRACT=Name]\n\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo

install: ## Fetch forge-std if it is missing (already bundled in the student zip)
	@if [ -d lib/forge-std/src ]; then echo "forge-std already present"; \
	elif [ -d .git ]; then forge install; \
	else forge install foundry-rs/forge-std --no-git; fi

doctor: ## Check tools, .env, and network reachability
	@bash scripts/doctor.sh

anvil: ## Start a local chain on http://127.0.0.1:8545 (keep this terminal open)
	anvil --block-time 2

build: ## Compile every contract in src/
	forge build

test: ## Run every test in test/
	forge test -vv

deploy: ## Deploy CONTRACT to NETWORK and record it in web/deployments.json
	@NETWORK=$(NETWORK) CONTRACT=$(CONTRACT) bash scripts/deploy.sh

verify: ## Verify CONTRACT source on the Prismo explorer
	@NETWORK=prismo CONTRACT=$(CONTRACT) bash scripts/verify.sh

dapp: ## Serve the dApps on http://localhost:3000
	node scripts/serve.js

new-dapp: ## Scaffold a new dApp: make new-dapp NAME=Voting
	@NAME=$(NAME) bash scripts/new-dapp.sh

did: ## DID demo, one step at a time: make did STEP=setup|resolve|issue|verify|tamper|rotate|retire|revoke
	@NETWORK=$(NETWORK) STEP=$(STEP) ARG=$(ARG) bash scripts/did-demo.sh

fund-students: ## Instructor: send gas to every address in students.txt
	@bash scripts/fund-students.sh

sync-design: ## Instructor: refresh the vendored Lumen design files
	@bash scripts/sync-design.sh

zip: ## Package the kit for students (excludes secrets and build output)
	@rm -f aim-smart-contracts-kit.zip
	@zip -qr aim-smart-contracts-kit.zip . -x '.env' 'students.txt' 'out/*' 'cache/*' 'broadcast/*' 'lib/forge-std/.git' 'web/deployments.json' 'did-demo/*' '.git/*' '*.zip' '.DS_Store' '*/.DS_Store'
	@echo "Wrote aim-smart-contracts-kit.zip. Students run: unzip, then make doctor."

clean: ## Remove build output
	forge clean
	rm -rf broadcast
