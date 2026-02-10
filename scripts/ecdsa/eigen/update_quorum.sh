#!/bin/bash

# -x echos all lines for debug
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
DEFAULT_SERVICE_MANAGER=$(jq -r '.addresses.WavsServiceManager' "$HOME/.nodes/avs_deploy.json" 2>/dev/null || true)
check_param "WAVS_SERVICE_MANAGER_ADDRESS" "${WAVS_SERVICE_MANAGER_ADDRESS:-$DEFAULT_SERVICE_MANAGER}"
check_param "QUORUM_NUMERATOR" "${QUORUM_NUMERATOR:-$1}"
check_param "QUORUM_DENOMINATOR" "${QUORUM_DENOMINATOR:-$2}"

# Set up environment based on DEPLOY_ENV
setup_environment

# Read the deployer private key
deployer_private_key=$(load_deployment_data "$HOME/.nodes/deployer")
check_param "FUNDED_KEY" "${FUNDED_KEY:-$deployer_private_key}"
deployer_address=$(cast wallet address "$FUNDED_KEY")
echo "Deployer address: $deployer_address"

# Ensure deployer has sufficient balance
ensure_balance "$deployer_address"

echo "WAVS_SERVICE_MANAGER_ADDRESS: $WAVS_SERVICE_MANAGER_ADDRESS"
echo "Updating quorum configuration to $QUORUM_NUMERATOR/$QUORUM_DENOMINATOR..."

# Update quorum configuration
cd contracts || handle_error "Failed to change to contracts directory"
# shellcheck source=../foundry_profile.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../foundry_profile.sh"
forge script script/eigenlayer/ecdsa/WavsUpdateQuorum.s.sol -vvv --rpc-url "$RPC_URL" --private-key "$FUNDED_KEY" --broadcast --skip-simulation || handle_error "Failed to update quorum configuration"

echo "Quorum configuration updated successfully"
