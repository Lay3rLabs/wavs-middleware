#!/bin/bash

# -x echos all lines for debug
# set -x

export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

set -o errexit -o nounset -o pipefail
command -v shellcheck >/dev/null && shellcheck "$0"

if [ "$DEPLOY_ENV" = "TESTNET" ]; then
    LOCAL_ETHEREUM_RPC_URL="$TESTNET_RPC_URL"
else
    LOCAL_ETHEREUM_RPC_URL=${LOCAL_ETHEREUM_RPC_URL:-http://localhost:8545}
fi

if [ -z "$WAVS_SERVICE_MANAGER_ADDRESS" ]; then
    echo "Error: WAVS_SERVICE_MANAGER_ADDRESS is not set in the environment variables (tip: grab from .nodes/avs_deploy.json)."
    exit 1
fi

cd contracts && forge script eigenlayer/script/WavsListOperators.s.sol -vvv --rpc-url $LOCAL_ETHEREUM_RPC_URL --broadcast
