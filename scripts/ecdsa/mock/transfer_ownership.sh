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
DEFAULT_SERVICE_MANAGER=$(jq -r '.addresses.WavsServiceManager' "$HOME/.nodes/mock.json" 2>/dev/null || true)
check_param "WAVS_SERVICE_MANAGER_ADDRESS" "${WAVS_SERVICE_MANAGER_ADDRESS:-$DEFAULT_SERVICE_MANAGER}"
check_param "PROXY_OWNER" "${PROXY_OWNER:-$1}"
check_param "AVS_OWNER" "${AVS_OWNER:-$2}"

# Set up environment based on DEPLOY_ENV
if [ "$DEPLOY_ENV" = "TESTNET" ]; then
    check_param "RPC_URL" "${MOCK_RPC_URL:-}"
else
    check_param "RPC_URL" "${MOCK_RPC_URL:-http://localhost:8546}"
fi

# Read the deployer private key
deployer_private_key=$(load_deployment_data "$HOME/.nodes/mock-deployer")
check_param "MOCK_DEPLOYER_KEY" "${MOCK_DEPLOYER_KEY:-$deployer_private_key}"
mock_deployer_address=$(cast wallet address "$MOCK_DEPLOYER_KEY")
echo "Deployer address: $mock_deployer_address"

ensure_balance "$mock_deployer_address"

transfer_ecdsa_ownership "$WAVS_SERVICE_MANAGER_ADDRESS" "$PROXY_OWNER" "$AVS_OWNER" "$MOCK_DEPLOYER_KEY" "mock"
