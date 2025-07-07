#!/bin/bash

# -x echos all lines for debug
# set -x

set -o errexit -o nounset -o pipefail
command -v shellcheck >/dev/null && shellcheck "$0"

export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

# Function to display error message and exit
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
# shellcheck source=./helpers.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR"/helpers.sh

# Read the deployer private key from file
if [ -f "$HOME/.nodes/deployer" ]; then
    deployer_private_key=$(cat "$HOME/.nodes/deployer")
    echo "Read deployer key from file."
    deployer_address=$(cast wallet address "$deployer_private_key")
    echo "Deployer address: $deployer_address"
else
    error_exit "Deployer key file not found at $HOME/.nodes/deployer"
fi

if [ "$DEPLOY_ENV" = "TESTNET" ]; then
    LOCAL_ETHEREUM_RPC_URL="$TESTNET_RPC_URL"
    if [ -z "$LOCAL_ETHEREUM_RPC_URL" ]; then
        error_exit "TESTNET_RPC_URL environment variable is not set"
    fi
else
    LOCAL_ETHEREUM_RPC_URL=${LOCAL_ETHEREUM_RPC_URL:-http://localhost:8545}
    wait_for_ethereum
    cast rpc anvil_setBalance $deployer_address 0x10000000000000000000 -r $LOCAL_ETHEREUM_RPC_URL > /dev/null 2>&1 || error_exit "Failed to set balance for deployer"
fi

# Get service manager address from environment variables or files
WAVS_SERVICE_MANAGER_ADDRESS=${WAVS_SERVICE_MANAGER_ADDRESS:-$(jq -r '.addresses.WavsServiceManager' "/root/.nodes/avs_deploy.json")}
if [ -z "${WAVS_SERVICE_MANAGER_ADDRESS:-}" ]; then
    error_exit "WAVS_SERVICE_MANAGER_ADDRESS is not set in environment variables or found in .nodes/avs_deploy.json"
fi
export WAVS_SERVICE_MANAGER_ADDRESS
echo "WAVS_SERVICE_MANAGER_ADDRESS: $WAVS_SERVICE_MANAGER_ADDRESS"

export QUORUM_NUMERATOR=${1}
export QUORUM_DENOMINATOR=${2}

echo "Updating quorum configuration..."
cd contracts && forge script eigenlayer/script/WavsUpdateQuorum.s.sol -vvv --rpc-url $LOCAL_ETHEREUM_RPC_URL --private-key $deployer_private_key --broadcast \
  || error_exit "Failed to run WavsUpdateQuorum"

echo "Quorum configuration updated successfully"
