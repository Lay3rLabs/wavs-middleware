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

# Get chain ID from mirror RPC URL
MIRROR_CHAIN_ID=$(get_chain_id "$MIRROR_RPC_URL")
export MIRROR_CHAIN_ID
echo "Mirror Chain ID: $MIRROR_CHAIN_ID"

# Read the deployer private key from file
deployer_private_key=$(load_deployment_data "$HOME/.nodes/deployer")
deployer_address=$(cast wallet address "$deployer_private_key")
echo "Deployer address: $deployer_address"

# Ensure deployer has sufficient balance on mirror chain
ensure_balance "$deployer_address" "$MIRROR_RPC_URL"

# Read service manager address from file
DEFAULT_SERVICE_MANAGER=$(jq -r '.addresses.WavsServiceManager' "$HOME/.nodes/avs_deploy.json" || true)
check_param "WAVS_SERVICE_MANAGER_ADDRESS" "${WAVS_SERVICE_MANAGER_ADDRESS:-$DEFAULT_SERVICE_MANAGER}"

echo "Reading source chain config:"

# Prepare deployment
cd contracts || handle_error "Failed to change to contracts directory"
forge script script/eigenlayer/ecdsa/WavsMirrorPrepareDeploy.s.sol --rpc-url "$SOURCE_RPC_URL" -vvv --broadcast || handle_error "Failed to run WavsMirrorPrepareDeploy script"

echo "Got config:"
cat "deployments/wavs-mirror-config.json"
ensure_dir deployments/wavs-mirror/

echo
echo "Deploying contracts"
forge script script/eigenlayer/ecdsa/WavsMirrorDeployer.s.sol --rpc-url "$MIRROR_RPC_URL" --private-key "$deployer_private_key" -vvv --broadcast || handle_error "Failed to deploy WavsMirrorDeployer"

echo "Mirror contracts deployed with addresses:"
cat "deployments/wavs-mirror/$MIRROR_CHAIN_ID.json" | jq .addresses

# Save deployment data
save_deployment_data "$HOME/.nodes/mirror-$MIRROR_CHAIN_ID.json" "$(cat "deployments/wavs-mirror/$MIRROR_CHAIN_ID.json")"
