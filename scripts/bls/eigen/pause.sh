#!/bin/bash

# Enable debug mode
# set -x

set -o errexit -o nounset -o pipefail
command -v shellcheck >/dev/null && shellcheck "$0"

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
# shellcheck source=../../helper.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../helper.sh"

# Parse command line arguments in key=value format
parse_args "$@"

# Check required parameters with defaults
check_param "DEPLOY_ENV" "${DEPLOY_ENV:-LOCAL}"
DEFAULT_REGISTRY_ADDRESS=$(jq -r '.addresses.registryCoordinator' "$HOME/.nodes/avs_deploy.json" || true)
check_param "REGISTRY_ADDRESS" "${REGISTRY_ADDRESS:-$DEFAULT_REGISTRY_ADDRESS}"

# Set up environment based on DEPLOY_ENV
setup_environment

# Read the deployer private key
deployer_private_key=$(load_deployment_data "$HOME/.nodes/deployer")
check_param "FUNDED_KEY" "${FUNDED_KEY:-$deployer_private_key}"
deployer_address=$(cast wallet address "$FUNDED_KEY")
echo "Deployer address: $deployer_address"

# Ensure deployer has sufficient balance
ensure_balance "$deployer_address"

echo "Pausing WAVS registration..."

# Pause registration
cd contracts || handle_error "Failed to change to contracts directory"
forge script script/eigenlayer/bls/PauseWavsRegistration.s.sol --rpc-url "$LOCAL_ETHEREUM_RPC_URL" --private-key "$FUNDED_KEY" --broadcast || handle_error "Failed to pause WAVS registration"

echo "WAVS registration paused successfully"
