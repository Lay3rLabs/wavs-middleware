#!/bin/bash

# Script to delegate to an operator using WavsDelegateToOperator.s.sol
# This script handles delegation to operators with proper signature verification

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

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
# shellcheck source=./helpers.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR"/helpers.sh

if [ -z "${STAKER_KEY:-}" ]; then
    error_exit "STAKER_KEY is not set in environment variables"
fi

mkdir -p ~/.nodes
staker_address=$(cast wallet address "$STAKER_KEY")
echo "$STAKER_KEY" > ~/.nodes/staker

# Get service manager address from environment variables or files
WAVS_SERVICE_MANAGER_ADDRESS=${WAVS_SERVICE_MANAGER_ADDRESS:-$(jq -r '.addresses.WavsServiceManager' "/root/.nodes/avs_deploy.json")}
if [ -z "${WAVS_SERVICE_MANAGER_ADDRESS:-}" ]; then
    error_exit "WAVS_SERVICE_MANAGER_ADDRESS is not set in environment variables or found in .nodes/avs_deploy.json"
fi
export WAVS_SERVICE_MANAGER_ADDRESS
echo "WAVS_SERVICE_MANAGER_ADDRESS: $WAVS_SERVICE_MANAGER_ADDRESS"

# Validate required environment variables
if [ -z "${OPERATOR_ADDRESS:-}" ]; then
    error_exit "OPERATOR_ADDRESS is not set in environment variables"
fi
export OPERATOR_ADDRESS
echo "OPERATOR_ADDRESS: $OPERATOR_ADDRESS"

if [ "$DEPLOY_ENV" = "TESTNET" ]; then
    LOCAL_ETHEREUM_RPC_URL="$TESTNET_RPC_URL"
    if [ -z "$LOCAL_ETHEREUM_RPC_URL" ]; then
        echo "Error: TESTNET_RPC_URL environment variable is not set"
        exit 1
    fi
else
    LOCAL_ETHEREUM_RPC_URL=${LOCAL_ETHEREUM_RPC_URL:-http://localhost:8545}
    wait_for_ethereum
    cast rpc anvil_setBalance $staker_address 0x10000000000000000000 -r $LOCAL_ETHEREUM_RPC_URL > /dev/null 2>&1 || (echo "Error: Failed to set balance for deployer" && exit 1)
fi

# Check if delegation approver private key is provided
if [ -n "${DELEGATION_APPROVER_PRIVATE_KEY:-}" ]; then
    export DELEGATION_APPROVER_PRIVATE_KEY
    echo "Using delegation approver private key"
else
    echo "Operator does not require delegation approval - no private key"
    export DELEGATION_APPROVER_PRIVATE_KEY="0x0000000000000000000000000000000000000000000000000000000000000000"
    echo "Using empty value for delegation approver private key"
fi

# Check if delegation approver salt is provided
if [ -n "${DELEGATION_APPROVER_SALT:-}" ]; then
    export DELEGATION_APPROVER_SALT
    echo "Using delegation approver salt"
else
    echo "Operator does not require delegation approval - no salt"
    export DELEGATION_APPROVER_SALT="0x0000000000000000000000000000000000000000000000000000000000000000"
    echo "Using empty value for delegation approver salt"
fi

# Check if delegation duration is provided
if [ -n "${DELEGATION_DURATION:-}" ]; then
    export DELEGATION_DURATION
    echo "Using delegation duration"
else
    echo "Operator does not require delegation approval - no duration"
    export DELEGATION_DURATION="0"
    echo "Using empty value for delegation duration"
fi

# Change to contracts directory and run the script
cd contracts || error_exit "Failed to change to contracts directory"
forge script eigenlayer/script/WavsDelegateToOperator.s.sol --rpc-url "$LOCAL_ETHEREUM_RPC_URL" --private-key "$STAKER_KEY" -vvv --broadcast || error_exit "Failed to delegate to operator"

echo "Successfully delegated to operator $OPERATOR_ADDRESS from staker $staker_address"
