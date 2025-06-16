#!/bin/bash

# -x echos all lines for debug
# set -x

set -o errexit -o nounset -o pipefail
command -v shellcheck >/dev/null && shellcheck "$0"

export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

if [ "$DEPLOY_ENV" = "TESTNET" ]; then
    LOCAL_ETHEREUM_RPC_URL="$TESTNET_RPC_URL"
else
    LOCAL_ETHEREUM_RPC_URL=${LOCAL_ETHEREUM_RPC_URL:-http://localhost:8545}
fi


# Env Vars
if [ -z "$LST_CONTRACT_ADDRESS" ]; then
    echo "Error: LST_CONTRACT_ADDRESS is not set in the environment variables."
    exit 1
fi
if [ -z "$LST_STRATEGY_ADDRESS" ]; then
    echo "Error: LST_STRATEGY_ADDRESS is not set in the environment variables."
    exit 1
fi

if [ -z "$WAVS_SERVICE_MANAGER_ADDRESS" ]; then
    echo "Error: WAVS_SERVICE_MANAGER_ADDRESS is not set in the environment variables (tip: grab from .nodes/avs_deploy.json)."
    exit 1
fi

# CLI Args
if [ -z "$1" ]; then
    echo "Error: Pass operator private key as first arg"
    exit 1
fi
OP_KEY="$1"
if [ -z "$2" ]; then
    echo "Error: Pass AVS signing key address as second arg"
    exit 1
fi
export WAVS_SIGNING_KEY="$2"
if [ -z "$3" ]; then
    echo "Error: Pass amount to deposit as third arg (0.01ether for example)"
    exit 1
fi
export WAVS_DELEGATE_AMOUNT="$3"

OP_ADDR=$(cast wallet address "$OP_KEY")
if [ "$DEPLOY_ENV" = "LOCAL" ]; then
    cast rpc anvil_setBalance $OP_ADDR 0x10000000000000000000 -r $LOCAL_ETHEREUM_RPC_URL > /dev/null 2>&1 || (echo "Error: Failed to set balance for operator" && exit 1)
fi

cd contracts && forge script eigenlayer/script/WavsRegisterOperator.s.sol -vvv --rpc-url $LOCAL_ETHEREUM_RPC_URL --private-key $OP_KEY --broadcast \
  || (echo "Error: Failed to run WavsRegisterOperator" && exit 1)
