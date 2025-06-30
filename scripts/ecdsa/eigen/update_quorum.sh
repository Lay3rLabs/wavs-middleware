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
check_param "WAVS_SERVICE_MANAGER_ADDRESS" "${WAVS_SERVICE_MANAGER_ADDRESS:-$(jq -r '.addresses.WavsServiceManager' "$HOME/.nodes/avs_deploy.json")}"
check_param "QUORUM_NUMERATOR" "${QUORUM_NUMERATOR:-1}"
check_param "QUORUM_DENOMINATOR" "${QUORUM_DENOMINATOR:-2}"

# Set up environment based on DEPLOY_ENV
setup_environment

# Read the deployer private key from file
deployer_private_key=$(load_deployment_data "$HOME/.nodes/deployer")
deployer_address=$(cast wallet address "$deployer_private_key")
echo "Deployer address: $deployer_address"

# Ensure deployer has sufficient balance
ensure_balance "$deployer_address"

echo "WAVS_SERVICE_MANAGER_ADDRESS: $WAVS_SERVICE_MANAGER_ADDRESS"

export QUORUM_NUMERATOR=${1}
export QUORUM_DENOMINATOR=${2}

echo "Updating quorum configuration..."
cd contracts && forge script eigenlayer/script/WavsUpdateQuorum.s.sol -vvv --rpc-url $LOCAL_ETHEREUM_RPC_URL --private-key $deployer_private_key --broadcast \
  || error_exit "Failed to run WavsUpdateQuorum"

echo "Quorum configuration updated successfully"
