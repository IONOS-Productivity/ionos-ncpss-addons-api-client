# Variables
OPENAPI_SPEC := openapi.json
GENERATOR_CLI := ./node_modules/.bin/openapi-generator-cli
GENERATOR_CONFIG := ./openapi-generator/php_lang.yaml
LIB_DIR := lib
TEST_DIR := test

# Get version from OpenAPI spec
VERSION := $(shell jq -r '.info.version' $(OPENAPI_SPEC) 2>/dev/null || echo "unknown")

# Phony targets
.PHONY: help clean generate_php_client cs_fix php check_dependencies

# Default target
.DEFAULT_GOAL := help

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

check_dependencies: ## Check if required dependencies are available
	@echo "Checking dependencies..."
	@command -v jq >/dev/null 2>&1 || { echo "Error: jq is required but not installed."; exit 1; }
	@test -f $(OPENAPI_SPEC) || { echo "Error: OpenAPI specification file $(OPENAPI_SPEC) not found."; exit 1; }
	@test -f $(GENERATOR_CLI) || { echo "Error: OpenAPI generator CLI not found. Run 'npm install' first."; exit 1; }
	@test -f $(GENERATOR_CONFIG) || { echo "Error: Generator configuration file $(GENERATOR_CONFIG) not found."; exit 1; }
	@echo "All dependencies are available."

clean: ## Remove generated content from test and lib folders
	@echo "Cleaning generated files..."
	@rm -rf $(TEST_DIR)/*
	@rm -rf $(LIB_DIR)/*
	@echo "Clean completed."

generate_php_client: check_dependencies ## Generate PHP client from OpenAPI specification
	@echo "Generating PHP client for version $(VERSION)..."
	$(GENERATOR_CLI) generate \
		--skip-validate-spec \
		-i $(OPENAPI_SPEC) \
		-g php \
		-o . \
		--global-property apiTests=true,modelTests=false \
		--additional-properties=httpUserAgent=ionos-ncpss-addons-api-client/$(VERSION)/PHP \
		-c $(GENERATOR_CONFIG)
	@echo "PHP client generation completed."

cs_fix: ## Fix code style using PHP CS Fixer
	@echo "Fixing code style..."
	composer cs:fix
	@echo "Code style fixes completed."

php: clean generate_php_client cs_fix ## Generate PHP client and apply code style fixes (full build)
	@echo "PHP client build completed successfully."
