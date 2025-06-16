#!/bin/bash

# -x echos all lines for debug
# set -x

set -o errexit -o nounset -o pipefail
command -v shellcheck >/dev/null && shellcheck "$0"

export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
# shellcheck source=./helpers.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR"/helpers.sh

# Check if METADATA_URI is provided
if [ -z "$METADATA_URI" ]; then
    echo "Error: METADATA_URI environment variable must be set"
    exit 1
fi

if [ -z "$FUNDED_KEY" ]; then
    echo "Error: FUNDED_KEY environment variable must be set"
    exit 1
fi

if [ -z "$LST_STRATEGY_ADDRESS" ]; then
    echo "Error: LST_STRATEGY_ADDRESS is not set in the environment variables."
    exit 1
fi

# prevents error where local run fails in rust script if you dont comment out TESTNET_RPC_URL in the env
if [ "$DEPLOY_ENV" = "LOCAL" ]; then
    unset TESTNET_RPC_URL
fi

#############################################
###### Start of script execution ############
#############################################

mkdir -p ~/.nodes
deployer_address=$(cast wallet address "$FUNDED_KEY")
echo "$FUNDED_KEY" > ~/.nodes/deployer

if [ "$DEPLOY_ENV" = "TESTNET" ]; then
    LOCAL_ETHEREUM_RPC_URL="$TESTNET_RPC_URL"
    if [ -z "$LOCAL_ETHEREUM_RPC_URL" ]; then
        echo "Error: TESTNET_RPC_URL environment variable is not set"
        exit 1
    fi
else
    wait_for_ethereum
    cast rpc anvil_setBalance $deployer_address 0x10000000000000000000 -r $LOCAL_ETHEREUM_RPC_URL > /dev/null 2>&1 || (echo "Error: Failed to set balance for deployer" && exit 1)
fi

echo "Deployer address: $deployer_address configured for $DEPLOY_ENV environment"

FUNDED_KEY_BAL=$(cast balance ${deployer_address} --rpc-url "$LOCAL_ETHEREUM_RPC_URL")
while [ "$FUNDED_KEY_BAL" = "0" ]; do
    if [ "$DEPLOY_ENV" = "LOCAL" ]; then
        cast rpc anvil_setBalance $deployer_address 0x10000000000000000000 -r $LOCAL_ETHEREUM_RPC_URL > /dev/null 2>&1 || (echo "Error: Failed to set balance for FUNDED_KEY" && exit 1)
    else
        echo "Waiting for FUNDED_KEY ${deployer_address} to have a balance. Current ${FUNDED_KEY_BAL}..."
        sleep 5
        FUNDED_KEY_BAL=$(cast balance ${deployer_address} --rpc-url "$LOCAL_ETHEREUM_RPC_URL")
    fi
done

cd contracts && forge script eigenlayer/script/WavsMiddlewareDeployer.s.sol --rpc-url $LOCAL_ETHEREUM_RPC_URL --private-key $FUNDED_KEY --broadcast || (echo "Error: Failed to deploy WavsMiddlewareDeployer" && exit 1)

echo "Middleware contracts deployed with addresses:"
cat deployments/wavs-middleware/$CHAIN_ID.json | jq .addresses
cp deployments/wavs-middleware/$CHAIN_ID.json ~/.nodes/avs_deploy.json

