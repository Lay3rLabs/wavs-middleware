#!/bin/bash

# Script to delegate to an operator using WavsDelegateToOperator.s.sol
# This script handles delegation to operators with proper signature verification

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

# Set up environment based on DEPLOY_ENV
setup_environment

# Check required parameters (can be from env or command line)
check_param "STAKER_KEY" "${STAKER_KEY:-}"
check_param "OPERATOR_ADDRESS" "${OPERATOR_ADDRESS:-}"
check_param "LST_CONTRACT_ADDRESS" "${LST_CONTRACT_ADDRESS:-}"
check_param "LST_STRATEGY_ADDRESS" "${LST_STRATEGY_ADDRESS:-}"
check_param "WAVS_DELEGATE_AMOUNT" "${WAVS_DELEGATE_AMOUNT:-$1}"
DEFAULT_SERVICE_MANAGER=$(jq -r '.addresses.WavsServiceManager' "$HOME/.nodes/avs_deploy.json" || true)
check_param "WAVS_SERVICE_MANAGER_ADDRESS" "${WAVS_SERVICE_MANAGER_ADDRESS:-$DEFAULT_SERVICE_MANAGER}"

# Optional parameters with defaults
check_param "DELEGATION_APPROVER_PRIVATE_KEY" "${DELEGATION_APPROVER_PRIVATE_KEY:-0x0000000000000000000000000000000000000000000000000000000000000000}"
check_param "DELEGATION_APPROVER_SALT" "${DELEGATION_APPROVER_SALT:-0x0000000000000000000000000000000000000000000000000000000000000000}"
check_param "DELEGATION_DURATION" "${DELEGATION_DURATION:-0}"

# Create necessary directories and save staker key
staker_address=$(cast wallet address "$STAKER_KEY")
echo "Staker address: $staker_address"

# Ensure staker has sufficient balance
ensure_balance "$staker_address"

echo "Delegating $WAVS_DELEGATE_AMOUNT to operator $OPERATOR_ADDRESS..."

# Change to contracts directory and run the script
cd contracts || handle_error "Failed to change to contracts directory"
forge script script/eigenlayer/ecdsa/WavsDelegateToOperator.s.sol --rpc-url "$RPC_URL" --private-key "$STAKER_KEY" -vvv --broadcast || handle_error "Failed to delegate to operator"

echo "Successfully delegated to operator $OPERATOR_ADDRESS from staker $staker_address"
