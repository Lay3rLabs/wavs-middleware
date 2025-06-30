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

# Set up environment based on DEPLOY_ENV
setup_environment

# Read the deployer private key from file
deployer_private_key=$(load_deployment_data "$HOME/.nodes/deployer")
deployer_address=$(cast wallet address "$deployer_private_key")
echo "Deployer address: $deployer_address"

# Ensure deployer has sufficient balance
ensure_balance "$deployer_address"

echo "Unpausing WAVS registration..."

# Unpause registration
cd contracts || handle_error "Failed to change to contracts directory"
forge script eigenlayer/script/UnpauseWavsRegistration.s.sol --rpc-url "$LOCAL_ETHEREUM_RPC_URL" --private-key "$deployer_private_key" --broadcast || handle_error "Failed to unpause WAVS registration"

echo "WAVS registration unpaused successfully"
