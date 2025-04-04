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
    local index=$1
    local WAVSServiceManagerAddress=$2
    if [ "$QUICK_MODE" = "ON" ] && [ "$index" -ne 1 ]; then
        echo "QUICK_MODE is ON - skipping operator setup for operator $index"
        return 0
    fi
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
    local mnemonic=$(cast wallet nm --json | jq -r '.mnemonic')
    local private_key=$(cast wallet pk "$mnemonic")
    local public_key=$(cast wallet address $private_key)
    
    if [ "$DEPLOY_ENV" = "TESTNET" ]; then
        cast s "$public_key" --value 50000000000000000 --private-key "$FUNDED_KEY" -r "$LOCAL_ETHEREUM_RPC_URL" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "Error: Failed to give operator $index balance"
            exit 1
        fi
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
    else
        cast rpc anvil_setBalance $public_key 0x10000000000000000000 -r $LOCAL_ETHEREUM_RPC_URL > /dev/null 2>&1
    fi
    if [ $? -ne 0 ]; then
        echo "Failed to set balance for operator $index"
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
    /wavs/register_layer_operator #> /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Failed to register operator $public_key to operator sets"
        exit 1
    fi
    echo "PRIVATE_KEY_${index}=$private_key" > ~/.nodes/operator$index
    echo "MNEMONIC_${index}=$mnemonic" > ~/.nodes/operator_mnemonic$index
}


# This function is used to register the operators to eigenlayer and the avs
if [ "$QUICK_MODE" = "ON" ]; then
    setup_operator 1 "$WAVSServiceManagerAddress"
else
    for i in $(seq 1 $NUM_OPERATORS); do
        setup_operator "$i" "$WAVSServiceManagerAddress"
    done
fi
