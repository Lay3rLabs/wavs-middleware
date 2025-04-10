#!/bin/bash

# -x echos all lines for debug
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

if [ -z "$LST_CONTRACT_ADDRESS" ]; then
    echo "Error: LST_CONTRACT_ADDRESS is not set in the environment variables."
    exit 1
fi
if [ -z "$LST_STRATEGY_ADDRESS" ]; then
    echo "Error: LST_STRATEGY_ADDRESS is not set in the environment variables."
    exit 1
fi
WAVSServiceManagerAddress=$(cat /root/.nodes/avs_deploy.json | jq -r '.addresses.WavsServiceManager')
if [ -z "$WAVSServiceManagerAddress" ]; then
    echo "Error: failed to read WavsServiceManager from /root/.nodes/avs_deploy.json"
    exit 1
fi

setup_operator() {
    local WAVSServiceManagerAddress=$1
    local private_key=$2
    local public_key=$(cast wallet address $private_key)

    STRATEGY_MANAGER_ADDRESS=$(jq -r '.addresses.strategyManager' contracts/deployments/core/$CHAIN_ID.json)
    if [ -z "$STRATEGY_MANAGER_ADDRESS" ]; then
        echo "Error: Failed to read strategyManagerAddress from contracts/deployments/core/$CHAIN_ID.json"
        exit 1
    fi
    DELEGATION_MANAGER_ADDRESS=$(jq -r '.addresses.delegation' contracts/deployments/core/$CHAIN_ID.json)
    if [ -z "$DELEGATION_MANAGER_ADDRESS" ]; then
        echo "Error: Failed to read delegationManagerAddress from contracts/deployments/core/$CHAIN_ID.json"
        exit 1
    fi

    
    if [ "$DEPLOY_ENV" = "TESTNET" ]; then
        # TODO: remove this and replace with a check the AVS key has a balance
        cast s "$public_key" --value 50000000000000000 --private-key "$FUNDED_KEY" -r "$LOCAL_ETHEREUM_RPC_URL" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "Error: Failed to give operator $index balance"
            exit 1
        fi
    else
        cast rpc anvil_setBalance $public_key 0x10000000000000000000 -r $LOCAL_ETHEREUM_RPC_URL > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "Failed to set balance for operator"
            exit 1
        fi
    fi

    # TODO: is this write? need proper LST addr setup in the .env file
    MINT_FUNCTION="submit(address _referral)"
    cast send "$LST_CONTRACT_ADDRESS" "$MINT_FUNCTION" "$public_key" "0x0000000000000000000000000000000000000000" \
        --private-key "$private_key" \
        --value 10000000000000000 \
        --rpc-url "$LOCAL_ETHEREUM_RPC_URL" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Failed to mint LST for $ADDRESS"
        exit 1
    fi
    cast send "$LST_CONTRACT_ADDRESS" "approve(address,uint256)" \
        "$STRATEGY_MANAGER_ADDRESS" 10000000000000000 \
        --private-key "$private_key" \
        --rpc-url "$LOCAL_ETHEREUM_RPC_URL" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Failed to approve LST for $STRATEGY_MANAGER_ADDRESS"
        exit 1
    fi
    cast send "$STRATEGY_MANAGER_ADDRESS" "depositIntoStrategy(address,address,uint256)" \
        "$LST_STRATEGY_ADDRESS" "$LST_CONTRACT_ADDRESS" 10000000000000000 \
        --private-key "$private_key" \
        --rpc-url "$LOCAL_ETHEREUM_RPC_URL" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Failed to deposit into strategy for $LST_STRATEGY_ADDRESS"
        exit 1
    fi


    cast send "$DELEGATION_MANAGER_ADDRESS" \
        "registerAsOperator(address,uint32,string)" \
        "$public_key" 0 "foo.bar" \
        --private-key "$private_key" \
        --rpc-url "$LOCAL_ETHEREUM_RPC_URL" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Failed to register as operator for $DELEGATION_MANAGER_ADDRESS"
        exit 1
    fi

    # TODO: what is this magic 0x1234 number here? Maybe we want a real variable for it?
    allocationManager=$(cast call "$WAVSServiceManagerAddress" "allocationManager()" --rpc-url "$LOCAL_ETHEREUM_RPC_URL" | cast parse-bytes32-address)
    cast s "$allocationManager" \
        "registerForOperatorSets(address,(address,uint32[],bytes))" \
        "$public_key" \
        "($WAVSServiceManagerAddress,[1],0x1234)" \
        --private-key "$private_key" \
        --rpc-url "$LOCAL_ETHEREUM_RPC_URL"  > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "Successfully registered operator $public_key to operator sets [1]"
    else
        echo "Error: Failed to register operator $public_key to operator sets"
        exit 1
    fi

    export PRIVATE_KEY=$private_key
    export TESTNET_RPC_URL="$LOCAL_ETHEREUM_RPC_URL"  

    # TODO: pull some stuff out of Rust into bash
    # See https://github.com/Lay3rLabs/wavs-middleware/issues/52
    # and https://github.com/Lay3rLabs/wavs-middleware/issues/42
    /wavs/register_wavs_operator #> /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Failed to register operator $public_key to operator sets"
        exit 1
    fi
}

if [ -z "$1" ]; then
    echo "Error: Pass private AVS Key as first arg"
    exit 1
fi
setup_operator "$WAVSServiceManagerAddress" "$1"
