#!/bin/bash

# Enable debug mode
# set -x

set -o errexit -o nounset -o pipefail
command -v shellcheck >/dev/null && shellcheck "$0"

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
# shellcheck source=./helpers.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR"/helpers.sh

if [ "$DEPLOY_ENV" = "TESTNET" ]; then
    LOCAL_ETHEREUM_RPC_URL="$TESTNET_RPC_URL"
else
    LOCAL_ETHEREUM_RPC_URL=${LOCAL_ETHEREUM_RPC_URL:-http://localhost:8545}
fi


if [ -f "/root/.nodes/deployer" ]; then
    DEPLOYER_KEY=$(cat "/root/.nodes/deployer")
else
    echo "Error: /root/.nodes/deployer file must exist"
    exit 1
fi

AVS_REGISTRAR_ADDRESS=$(cat /root/.nodes/avs_deploy.json | jq -r '.addresses.avsRegistrar')
echo "AVS Registrar address: $AVS_REGISTRAR_ADDRESS"

# Call the pause function on the AVS Registrar
echo "Pausing AVS Registrar..."
cast send --private-key "$DEPLOYER_KEY" \
    "$AVS_REGISTRAR_ADDRESS" \
    "pause()" \
    --rpc-url "$LOCAL_ETHEREUM_RPC_URL"

# Verify that the AVS Registrar is paused
echo "Verifying AVS Registrar is paused..."
IS_PAUSED=$(cast call "$AVS_REGISTRAR_ADDRESS" "isPaused()" --rpc-url "$LOCAL_ETHEREUM_RPC_URL")
echo "Paused: $IS_PAUSED"

if [ "$IS_PAUSED" = "true" ] || [ "$IS_PAUSED" = "0x0000000000000000000000000000000000000000000000000000000000000001" ]; then
    echo "AVS Registrar has been successfully paused"
else
    echo "Error: Failed to pause AVS Registrar"
    exit 1
fi
