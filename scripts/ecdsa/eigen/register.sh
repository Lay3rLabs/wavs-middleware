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
check_param "LST_CONTRACT_ADDRESS" "${LST_CONTRACT_ADDRESS:-}"
check_param "LST_STRATEGY_ADDRESS" "${LST_STRATEGY_ADDRESS:-}"
DEFAULT_SERVICE_MANAGER=$(jq -r '.addresses.WavsServiceManager' "$HOME/.nodes/avs_deploy.json" || true)
check_param "WAVS_SERVICE_MANAGER_ADDRESS" "${WAVS_SERVICE_MANAGER_ADDRESS:-$DEFAULT_SERVICE_MANAGER}"
check_param "OPERATOR_KEY" "${OPERATOR_KEY:-}"
check_param "WAVS_SIGNING_KEY" "${WAVS_SIGNING_KEY:-}"
check_param "WAVS_DELEGATE_AMOUNT" "${WAVS_DELEGATE_AMOUNT:-$1}"

# Set up environment based on DEPLOY_ENV
setup_environment

# Get operator address
OP_ADDR=$(cast wallet address "$OPERATOR_KEY")

# Ensure operator has sufficient balance
ensure_balance "$OP_ADDR"

echo "Operator address: $OP_ADDR"

# Register operator
cd contracts || handle_error "Failed to change to contracts directory"
forge script script/eigenlayer/ecdsa/WavsRegisterOperator.s.sol -vvv --rpc-url "$LOCAL_ETHEREUM_RPC_URL" --private-key "$OPERATOR_KEY" --broadcast || handle_error "Failed to register operator"
