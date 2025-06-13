#!/bin/bash

# -x echos all lines for debug
# set -x

export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

set -o errexit -o nounset -o pipefail
command -v shellcheck >/dev/null && shellcheck "$0"

if [ "$DEPLOY_ENV" = "TESTNET" ]; then
    SOURCE_RPC_URL=${SOURCE_RPC_URL:-}
else
    SOURCE_RPC_URL=${SOURCE_RPC_URL:-http://localhost:8545}
fi
if [ "$DEPLOY_ENV" = "TESTNET" ]; then
    MIRROR_RPC_URL=${MIRROR_RPC_URL:-}
else
    MIRROR_RPC_URL=${MIRROR_RPC_URL:-http://localhost:8546}
fi

if [ -z "$SOURCE_RPC_URL" ]; then
    echo "Error: SOURCE_RPC_URL is not set in the environment variables (tip: grab from .nodes/avs_deploy.json)."
    exit 1
fi

if [ -z "$MIRROR_RPC_URL" ]; then
    echo "Error: MIRROR_RPC_URL is not set in the environment variables (tip: grab from .nodes/avs_deploy.json)."
    exit 1
fi

# Set arbitrary location for config
export WAVS_MIRROR_CONFIG="/wavs/contracts/deployments/wavs-mirror-config.json"

# Read the deployer private key from file
if [ -f "$HOME/.nodes/deployer" ]; then
    deployer_private_key=$(cat "$HOME/.nodes/deployer")
    echo "Read deployer key from file."
    deployer_address=$(cast wallet address "$deployer_private_key")
    echo "Deployer address: $deployer_address"
else
    echo "Error: Deployer key file not found at $HOME/.nodes/deployer"
    exit 1
fi


if [ "$DEPLOY_ENV" = "LOCAL" ]; then
    echo "Set gas balancer for deployer on mirror chain"
    cast rpc anvil_setBalance $deployer_address 0x10000000000000000000 -r $MIRROR_RPC_URL > /dev/null 2>&1 || (echo "Error: Failed to set balance for deployer" && exit 1)
fi


# Read service manager address from file
export WAVS_SERVICE_MANAGER_ADDRESS=$(jq -r '.addresses.WavsServiceManager' /root/.nodes/avs_deploy.json)

echo "Reading source chain config:"

cd contracts
forge script eigenlayer/script/WavsMirrorPrepareDeploy.s.sol --rpc-url $SOURCE_RPC_URL -vv --broadcast

echo "Got config:"
cat $WAVS_MIRROR_CONFIG
mkdir -p deployments/wavs-mirror/

echo
echo "Deploying contracts"
forge script eigenlayer/script/WavsMirrorDeployer.s.sol --rpc-url $MIRROR_RPC_URL --private-key $deployer_private_key -vv --broadcast
cat deployments/wavs-mirror/31337.json
