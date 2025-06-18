#!/bin/bash

# Script to list operators from both source and mirror chains
# This script reads operator information from the source chain and their corresponding weights from the mirror chain

# Enable strict error handling
set -o errexit -o nounset -o pipefail

# Disable Foundry nightly warning
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

# Check for required tools
command -v shellcheck >/dev/null && shellcheck "$0"
command -v jq >/dev/null || { echo "Error: jq is required but not installed"; exit 1; }
command -v cast >/dev/null || { echo "Error: cast is required but not installed"; exit 1; }

# Function to display error message and exit
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# Function to validate RPC URL
validate_rpc_url() {
    local url=$1
    local name=$2
    
    if [ -z "$url" ]; then
        error_exit "$name is not set in the environment variables (tip: grab from .nodes/avs_deploy.json)"
    fi
    
    # Basic URL validation
    if ! [[ "$url" =~ ^https?:// ]]; then
        error_exit "$name must be a valid HTTP/HTTPS URL"
    fi
}

# Set RPC URLs based on environment
if [ "${DEPLOY_ENV:-}" = "TESTNET" ]; then
    SOURCE_RPC_URL=${SOURCE_RPC_URL:-}
    MIRROR_RPC_URL=${MIRROR_RPC_URL:-}
else
    SOURCE_RPC_URL=${SOURCE_RPC_URL:-http://localhost:8545}
    MIRROR_RPC_URL=${MIRROR_RPC_URL:-http://localhost:8546}
fi

# Validate RPC URLs
validate_rpc_url "$SOURCE_RPC_URL" "SOURCE_RPC_URL"
validate_rpc_url "$MIRROR_RPC_URL" "MIRROR_RPC_URL"

# Get chain ID from mirror RPC URL
MIRROR_CHAIN_ID=$(cast chain-id --rpc-url "$MIRROR_RPC_URL") || error_exit "Failed to get chain ID from mirror RPC URL"
export MIRROR_CHAIN_ID
echo "Mirror Chain ID: $MIRROR_CHAIN_ID"

# Read service manager addresses from JSON files
WAVS_SERVICE_MANAGER_ADDRESS=$(jq -r '.addresses.WavsServiceManager' /root/.nodes/avs_deploy.json) || error_exit "Failed to read WAVS_SERVICE_MANAGER_ADDRESS from avs_deploy.json"
MIRROR_SERVICE_MANAGER_ADDRESS=$(jq -r '.addresses.WavsServiceManager' "/root/.nodes/mirror-$MIRROR_CHAIN_ID.json") || error_exit "Failed to read MIRROR_SERVICE_MANAGER_ADDRESS from mirror-$MIRROR_CHAIN_ID.json"

# Export addresses for the script
export WAVS_SERVICE_MANAGER_ADDRESS
export MIRROR_SERVICE_MANAGER_ADDRESS

# Change to contracts directory and run the script
cd contracts || error_exit "Failed to change to contracts directory"
forge script eigenlayer/script/WavsMirrorListOperators.s.sol -vvv --broadcast
