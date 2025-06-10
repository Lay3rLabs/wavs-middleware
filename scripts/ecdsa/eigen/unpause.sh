#!/bin/bash

# Enable debug mode
# set -x

set -o errexit -o nounset -o pipefail
command -v shellcheck >/dev/null && shellcheck "$0"

if [ "$DEPLOY_ENV" = "TESTNET" ]; then
    LOCAL_ETHEREUM_RPC_URL="$TESTNET_RPC_URL"
else
    LOCAL_ETHEREUM_RPC_URL=${LOCAL_ETHEREUM_RPC_URL:-http://localhost:8545}
fi

# TODO: this should work outside docker as well - $HOME/.nodes/deployer ?
# We can also pass in AVS_DEPLOY_FILE for avs_deploy.json path
if [ -f "/root/.nodes/deployer" ]; then
    DEPLOYER_KEY=$(cat "/root/.nodes/deployer")
else
    echo "Error: /root/.nodes/deployer file must exist"
    exit 1
fi


cd contracts
forge script eigenlayer/script/UnpauseWavsRegistration.s.sol --rpc-url $LOCAL_ETHEREUM_RPC_URL --private-key $DEPLOYER_KEY --broadcast
