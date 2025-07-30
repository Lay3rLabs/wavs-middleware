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
DEFAULT_SERVICE_MANAGER=$(jq -r '.addresses.WavsServiceManager' "$HOME/.nodes/avs_deploy.json" 2>/dev/null || true)
check_param "WAVS_SERVICE_MANAGER_ADDRESS" "${WAVS_SERVICE_MANAGER_ADDRESS:-$DEFAULT_SERVICE_MANAGER}"

# Set up environment based on DEPLOY_ENV
setup_environment

echo "Listing operators for service manager: $WAVS_SERVICE_MANAGER_ADDRESS"

# List operators
cd contracts || handle_error "Failed to change to contracts directory"
forge script script/eigenlayer/ecdsa/WavsListOperators.s.sol -vvv --rpc-url "$RPC_URL" --broadcast --skip-simulation || handle_error "Failed to list operators"
