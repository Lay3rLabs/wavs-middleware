#!/bin/bash

# -x echos all lines for debug
# set -x

set -o errexit -o nounset -o pipefail
command -v shellcheck >/dev/null && shellcheck "$0"

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
# shellcheck source=../../helper.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../helper.sh"

# shellcheck source=../foundry_profile.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../foundry_profile.sh"

# Parse command line arguments in key=value format
parse_args "$@"

# Check required parameters with defaults
check_param "DEPLOY_ENV" "${DEPLOY_ENV:-LOCAL}"
check_param "DEPLOY_FILE_MOCK" "${DEPLOY_FILE_MOCK:-mock}"
check_param "CONFIGURE_FILE" "${CONFIGURE_FILE:-wavs-mock-config}"

DEFAULT_MOCK_SERVICE_MANAGER_ADDRESS=$(jq -r '.addresses.WavsServiceManager' "$HOME/.nodes/${DEPLOY_FILE_MOCK}.json" 2>/dev/null || true)
check_param "MOCK_SERVICE_MANAGER_ADDRESS" "${MOCK_SERVICE_MANAGER_ADDRESS:-$DEFAULT_MOCK_SERVICE_MANAGER_ADDRESS}"

# Set up RPC URL based on environment
if [ "$DEPLOY_ENV" = "TESTNET" ]; then
    check_param "MOCK_RPC_URL" "${MOCK_RPC_URL:-}"
else
    check_param "MOCK_RPC_URL" "${MOCK_RPC_URL:-http://localhost:8546}"
fi

# Check required parameters
mock_deployer_private_key=$(load_deployment_data "$HOME/.nodes/mock-deployer")
check_param "MOCK_DEPLOYER_KEY" "${MOCK_DEPLOYER_KEY:-$mock_deployer_private_key}"
mock_deployer_address=$(cast wallet address "$MOCK_DEPLOYER_KEY")
echo "Mock deployer address: $mock_deployer_address" 

# Ensure deployer has sufficient balance
ensure_balance "$mock_deployer_address" "$MOCK_RPC_URL"

echo "Mock deployer address: $mock_deployer_address"
echo "Configuring mock contracts"

# Configure contracts
cd contracts || handle_error "Failed to change to contracts directory"

forge script script/eigenlayer/ecdsa/WavsMockConfiguration.s.sol --rpc-url "$MOCK_RPC_URL" --private-key "$MOCK_DEPLOYER_KEY" -vvv --broadcast --skip-simulation || handle_error "Failed to configure WavsMockDeployer"

echo "Mock contracts configured successfully"
