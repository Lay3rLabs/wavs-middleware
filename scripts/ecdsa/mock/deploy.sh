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

if [ -z "${MOCK_DEPLOYER_KEY:-}" ]; then
    error_exit "MOCK_DEPLOYER_KEY is not set in environment variables"
fi

MOCK_DEPLOYER_ADDRESS=$(cast wallet address "$MOCK_DEPLOYER_KEY") || error_exit "Failed to get deployer address"
mkdir -p ~/.nodes
echo "$MOCK_DEPLOYER_KEY" > ~/.nodes/mock-deployer

if [ "$DEPLOY_ENV" = "LOCAL" ]; then
    echo "Set gas balancer for deployer on mock chain"
    cast rpc anvil_setBalance "$MOCK_DEPLOYER_ADDRESS" 0x10000000000000000000 -r "$MOCK_RPC_URL" > /dev/null 2>&1 || error_exit "Failed to set balance for deployer"
else
    FUNDED_KEY_BAL=$(cast balance "${MOCK_DEPLOYER_ADDRESS}" --rpc-url "$MOCK_RPC_URL") || error_exit "Failed to get deployer balance"
    while [ "$FUNDED_KEY_BAL" = "0" ]; do
        echo "Waiting for FUNDED_KEY ${MOCK_DEPLOYER_ADDRESS} to have a balance on ${MOCK_RPC_URL}."
        sleep 5
        FUNDED_KEY_BAL=$(cast balance "${MOCK_DEPLOYER_ADDRESS}" --rpc-url "$MOCK_RPC_URL") || error_exit "Failed to get deployer balance"
    done
fi

cd contracts || error_exit "Failed to change to contracts directory"

mkdir -p deployments/wavs-mock/

echo "Deployer address: $MOCK_DEPLOYER_ADDRESS"
echo "Deploying contracts"
forge script eigenlayer/script/WavsMockDeployer.s.sol --rpc-url "$MOCK_RPC_URL" --private-key "$MOCK_DEPLOYER_KEY" -vvv --broadcast || error_exit "Failed to deploy WavsMockDeployer"

echo "Mock contracts deployed with addresses:"
cat "deployments/wavs-mock/$MOCK_CHAIN_ID.json" | jq .addresses
cp "deployments/wavs-mock/$MOCK_CHAIN_ID.json" "/root/.nodes/mock-$MOCK_CHAIN_ID.json"
