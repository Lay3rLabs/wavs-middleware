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
    MOCK_RPC_URL=${MOCK_RPC_URL:-}
else
    MOCK_RPC_URL=${MOCK_RPC_URL:-http://localhost:8546}
fi

# Validate RPC URLs
if [ -z "$MOCK_RPC_URL" ]; then
    error_exit "MOCK_RPC_URL is not set in the environment variables (tip: grab from .nodes/avs_deploy.json)"
fi

# Get chain ID from rpc url
MOCK_CHAIN_ID=$(cast chain-id --rpc-url "$MOCK_RPC_URL") || error_exit "Failed to get chain ID from RPC URL"
export MOCK_CHAIN_ID
echo "Chain ID: $MOCK_CHAIN_ID"

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
    echo "Set gas balancer for deployer on mock chain"
    cast rpc anvil_setBalance "$deployer_address" 0x10000000000000000000 -r "$MOCK_RPC_URL" > /dev/null 2>&1 || error_exit "Failed to set balance for deployer"
else
    FUNDED_KEY_BAL=$(cast balance "${deployer_address}" --rpc-url "$MOCK_RPC_URL") || error_exit "Failed to get deployer balance"
    while [ "$FUNDED_KEY_BAL" = "0" ]; do
        echo "Waiting for FUNDED_KEY ${deployer_address} to have a balance on ${MOCK_RPC_URL}."
        sleep 5
        FUNDED_KEY_BAL=$(cast balance "${deployer_address}" --rpc-url "$MOCK_RPC_URL") || error_exit "Failed to get deployer balance"
    done
fi

cd contracts || error_exit "Failed to change to contracts directory"
# Config file must be provided from outside via an environment variable
WAVS_MOCK_CONFIG=${WAVS_MOCK_CONFIG:-./deployments/wavs-mock-config.json}
# if [ ! -f "$WAVS_MOCK_CONFIG" ]; then
#     error_exit "Mock config file not found at $WAVS_MOCK_CONFIG"
# fi

echo "Reading config from: $WAVS_MOCK_CONFIG"
cat "$WAVS_MOCK_CONFIG"
export WAVS_MOCK_CONFIG


mkdir -p deployments/wavs-mock/

echo
echo "Deploying contracts"
forge script eigenlayer/script/WavsMockDeployer.s.sol --rpc-url "$MOCK_RPC_URL" --private-key "$deployer_private_key" -vvv --broadcast || error_exit "Failed to deploy WavsMockDeployer"

echo "Mock contracts deployed with addresses:"
cat "deployments/wavs-mock/$MOCK_CHAIN_ID.json" | jq .addresses
cp "deployments/wavs-mock/$MOCK_CHAIN_ID.json" "/root/.nodes/mock-$MOCK_CHAIN_ID.json"
