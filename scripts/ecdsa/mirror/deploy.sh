#!/bin/bash

# -x echos all lines for debug
# set -x

export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

set -o errexit -o nounset -o pipefail
command -v shellcheck >/dev/null && shellcheck "$0"

# Function to display error message and exit
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# Set RPC URLs based on environment
if [ "$DEPLOY_ENV" = "TESTNET" ]; then
    SOURCE_RPC_URL=${SOURCE_RPC_URL:-}
    MIRROR_RPC_URL=${MIRROR_RPC_URL:-}
else
    SOURCE_RPC_URL=${SOURCE_RPC_URL:-http://localhost:8545}
    MIRROR_RPC_URL=${MIRROR_RPC_URL:-http://localhost:8546}
fi

# Validate RPC URLs
if [ -z "$SOURCE_RPC_URL" ]; then
    error_exit "SOURCE_RPC_URL is not set in the environment variables (tip: grab from .nodes/avs_deploy.json)"
fi

if [ -z "$MIRROR_RPC_URL" ]; then
    error_exit "MIRROR_RPC_URL is not set in the environment variables (tip: grab from .nodes/avs_deploy.json)"
fi

# Get chain ID from mirror RPC URL
MIRROR_CHAIN_ID=$(cast chain-id --rpc-url "$MIRROR_RPC_URL") || error_exit "Failed to get chain ID from mirror RPC URL"
export MIRROR_CHAIN_ID
echo "Mirror Chain ID: $MIRROR_CHAIN_ID"

# Read the deployer private key from file
if [ -f "$HOME/.nodes/deployer" ]; then
    deployer_private_key=$(cat "$HOME/.nodes/deployer")
    echo "Read deployer key from file."
    deployer_address=$(cast wallet address "$deployer_private_key") || error_exit "Failed to get deployer address"
    echo "Deployer address: $deployer_address"
else
    error_exit "Deployer key file not found at $HOME/.nodes/deployer"
fi

if [ "$DEPLOY_ENV" = "LOCAL" ]; then
    echo "Set gas balancer for deployer on mirror chain"
    cast rpc anvil_setBalance "$deployer_address" 0x10000000000000000000 -r "$MIRROR_RPC_URL" > /dev/null 2>&1 || error_exit "Failed to set balance for deployer"
else
    FUNDED_KEY_BAL=$(cast balance "${deployer_address}" --rpc-url "$MIRROR_RPC_URL") || error_exit "Failed to get deployer balance"
    while [ "$FUNDED_KEY_BAL" = "0" ]; do
        echo "Waiting for FUNDED_KEY ${deployer_address} to have a balance on ${MIRROR_RPC_URL}."
        sleep 5
        FUNDED_KEY_BAL=$(cast balance "${deployer_address}" --rpc-url "$MIRROR_RPC_URL") || error_exit "Failed to get deployer balance"
    done
fi

# Read service manager address from file
export WAVS_SERVICE_MANAGER_ADDRESS=$(jq -r '.addresses.WavsServiceManager' /root/.nodes/avs_deploy.json) || error_exit "Failed to read WAVS_SERVICE_MANAGER_ADDRESS from avs_deploy.json"

# Set arbitrary location for config
export WAVS_MIRROR_CONFIG=${WAVS_MIRROR_CONFIG:-./deployments/wavs-mirror-config.json}

echo "Reading source chain config:"

cd contracts || error_exit "Failed to change to contracts directory"
forge script eigenlayer/script/WavsMirrorPrepareDeploy.s.sol --rpc-url "$SOURCE_RPC_URL" -vvv --broadcast || error_exit "Failed to run WavsMirrorPrepareDeploy script"

echo "Got config:"
cat "$WAVS_MIRROR_CONFIG"
mkdir -p deployments/wavs-mirror/

echo
echo "Deploying contracts"
forge script eigenlayer/script/WavsMirrorDeployer.s.sol --rpc-url "$MIRROR_RPC_URL" --private-key "$deployer_private_key" -vvv --broadcast || error_exit "Failed to deploy WavsMirrorDeployer"

echo "Mirror contracts deployed with addresses:"
cat "deployments/wavs-mirror/$MIRROR_CHAIN_ID.json" | jq .addresses
cp "deployments/wavs-mirror/$MIRROR_CHAIN_ID.json" "/root/.nodes/mirror-$MIRROR_CHAIN_ID.json"
