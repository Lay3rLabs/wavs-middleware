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

# Set up environment based on DEPLOY_ENV
if [ "$DEPLOY_ENV" = "TESTNET" ]; then
    check_param "SOURCE_RPC_URL" "${SOURCE_RPC_URL:-}"
    check_param "MIRROR_RPC_URL" "${MIRROR_RPC_URL:-}"
else
    check_param "SOURCE_RPC_URL" "${SOURCE_RPC_URL:-http://localhost:8545}"
    check_param "MIRROR_RPC_URL" "${MIRROR_RPC_URL:-http://localhost:8546}"
fi

# Read the deployer private key
deployer_private_key=$(load_deployment_data "$HOME/.nodes/deployer")
check_param "FUNDED_KEY" "${FUNDED_KEY:-$deployer_private_key}"
deployer_address=$(cast wallet address "$FUNDED_KEY")
echo "Deployer address: $deployer_address"

# Ensure deployer has sufficient balance on mirror chain
ensure_balance "$deployer_address" "$MIRROR_RPC_URL"

# Read service manager address from file
DEFAULT_SERVICE_MANAGER=$(jq -r '.addresses.WavsServiceManager' "$HOME/.nodes/avs_deploy.json" 2>/dev/null || true)
check_param "WAVS_SERVICE_MANAGER_ADDRESS" "${WAVS_SERVICE_MANAGER_ADDRESS:-$DEFAULT_SERVICE_MANAGER}"

echo "Reading source chain config:"

# Prepare deployment
cd contracts || handle_error "Failed to change to contracts directory"

# shellcheck source=../foundry_profile.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../foundry_profile.sh"

forge script script/eigenlayer/ecdsa/WavsMirrorPrepareDeploy.s.sol --rpc-url "$SOURCE_RPC_URL" -vvv --broadcast --skip-simulation || handle_error "Failed to run WavsMirrorPrepareDeploy script"

echo "Got config:"
cat "deployments/wavs-mirror-config.json"

echo
echo "Deploying contracts"
forge script script/eigenlayer/ecdsa/WavsMirrorDeployer.s.sol --rpc-url "$MIRROR_RPC_URL" --private-key "$FUNDED_KEY" -vvv --broadcast --skip-simulation || handle_error "Failed to deploy WavsMirrorDeployer"

echo "Mirror contracts deployed with addresses:"
cat "deployments/wavs-ecdsa/mirror_deploy.json" | jq .addresses

# Save deployment data
save_deployment_data "$HOME/.nodes/mirror.json" "$(cat "deployments/wavs-ecdsa/mirror_deploy.json")"
