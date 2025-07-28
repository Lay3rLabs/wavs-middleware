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

# Set up RPC URL based on environment
if [ "$DEPLOY_ENV" = "TESTNET" ]; then
    check_param "MOCK_RPC_URL" "${MOCK_RPC_URL:-}"
else
    check_param "MOCK_RPC_URL" "${MOCK_RPC_URL:-http://localhost:8546}"
fi

# Check required parameters
check_param "MOCK_DEPLOYER_KEY" "${MOCK_DEPLOYER_KEY:-}"
check_param "DEPLOY_FILE_MOCK" "${DEPLOY_FILE_MOCK:-mock}"

# Get deployer address and save private key
MOCK_DEPLOYER_ADDRESS=$(cast wallet address "$MOCK_DEPLOYER_KEY")
ensure_dir "$HOME/.nodes"
save_deployment_data "$HOME/.nodes/mock-deployer" "$MOCK_DEPLOYER_KEY"

# Ensure deployer has sufficient balance
ensure_balance "$MOCK_DEPLOYER_ADDRESS" "$MOCK_RPC_URL"

echo "Deployer address: $MOCK_DEPLOYER_ADDRESS"
echo "Deploying contracts"

# Deploy contracts
cd contracts || handle_error "Failed to change to contracts directory"

forge script script/eigenlayer/ecdsa/WavsMockDeployer.s.sol --rpc-url "$MOCK_RPC_URL" --private-key "$MOCK_DEPLOYER_KEY" -vvv --broadcast || handle_error "Failed to deploy WavsMockDeployer"

echo "Mock contracts deployed with addresses:"
cat "deployments/wavs-ecdsa/${DEPLOY_FILE_MOCK}.json" | jq .addresses

# Save deployment data
save_deployment_data "$HOME/.nodes/${DEPLOY_FILE_MOCK}.json" "$(cat "deployments/wavs-ecdsa/${DEPLOY_FILE_MOCK}.json")"
