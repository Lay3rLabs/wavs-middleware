#!/bin/bash

# Script to list operators from both source and mirror chains
# This script reads operator information from the source chain and their corresponding weights from the mirror chain

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

# Set up RPC URLs based on environment
if [ "$DEPLOY_ENV" = "TESTNET" ]; then
    check_param "SOURCE_RPC_URL" "${SOURCE_RPC_URL:-}"
    check_param "MIRROR_RPC_URL" "${MIRROR_RPC_URL:-}"
else
    check_param "SOURCE_RPC_URL" "${SOURCE_RPC_URL:-http://localhost:8545}"
    check_param "MIRROR_RPC_URL" "${MIRROR_RPC_URL:-http://localhost:8546}"
fi

# Get service manager addresses from environment variables or files
DEFAULT_SOURCE_SERVICE_MANAGER=$(jq -r '.addresses.WavsServiceManager' "$HOME/.nodes/avs_deploy.json" 2>/dev/null || true)
check_param "SOURCE_SERVICE_MANAGER_ADDRESS" "${SOURCE_SERVICE_MANAGER_ADDRESS:-$DEFAULT_SOURCE_SERVICE_MANAGER}"
DEFAULT_MIRROR_SERVICE_MANAGER=$(jq -r '.addresses.WavsServiceManager' "$HOME/.nodes/mirror.json" 2>/dev/null || true)
check_param "MIRROR_SERVICE_MANAGER_ADDRESS" "${MIRROR_SERVICE_MANAGER_ADDRESS:-$DEFAULT_MIRROR_SERVICE_MANAGER}"

# Change to contracts directory and run the script
cd contracts || handle_error "Failed to change to contracts directory"
forge script script/eigenlayer/ecdsa/WavsMirrorListOperators.s.sol -vvv --broadcast --skip-simulation || handle_error "Failed to list operators"

echo "Operator list:"
cat "deployments/wavs-ecdsa/mirror_list_operators.json" | jq .

# Save operator list data
save_deployment_data "$HOME/.nodes/mirror-list-operators.json" "$(cat "deployments/wavs-ecdsa/mirror_list_operators.json")"
