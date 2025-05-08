#!/bin/bash

# -x echos all lines for debug
set -x

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

# Function to register operator with AVS using cast commands
register_operator_with_avs() {
    echo "Registering operator with AVS..."
    local private_key=$1
    local public_key=$(cast wallet address $private_key)

    echo "Registering operator $public_key with AVS..."
    local stake_registry_address=$(cat /root/.nodes/avs_deploy.json | jq -r '.addresses.stakeRegistry')
    if [ -z "$stake_registry_address" ]; then
        echo "Error: Failed to read StakeRegistry from /root/.nodes/avs_deploy.json"
        exit 1
    fi
    local service_manager_address=$(cat /root/.nodes/avs_deploy.json | jq -r '.addresses.WavsServiceManager')
    if [ -z "$service_manager_address" ]; then
        echo "Error: Failed to read WavsServiceManager from /root/.nodes/avs_deploy.json"
        exit 1
    fi
    local avs_directory_address=$(cast call "$service_manager_address" "avsDirectory()" --rpc-url "$LOCAL_ETHEREUM_RPC_URL" | cast parse-bytes32-address)
    if [ -z "$avs_directory_address" ]; then
        echo "Error: Failed to read AVSDirectory from /root/.nodes/avs_deploy.json"
        exit 1
    fi
    # Generate a random salt (32 bytes)
    local salt=$(openssl rand -hex 32)

    # Calculate expiry (current time + 1 hour)
    local expiry=$(($(date +%s) + 3600))

    local digest_hash=$(cast call "$avs_directory_address" "calculateOperatorAVSRegistrationDigestHash(address,address,bytes32,uint256)" "$public_key" "$service_manager_address" "$salt" "$expiry" --rpc-url "$LOCAL_ETHEREUM_RPC_URL")
    # Remove 0x prefix from digest hash if present
    digest_hash=${digest_hash#0x}
    # Sign the digest hash with the private key
    local signature=$(cast wallet sign $digest_hash --no-hash --private-key "$private_key")

    # Register the operator with the signature
    echo "Registering operator with signature..."
    cast c --trace "$stake_registry_address" \
        "registerOperatorWithSignature((bytes,bytes32,uint256),address)" \
        "($signature,$salt,$expiry)" "$public_key" \
        --private-key "$private_key" \
        --rpc-url "$LOCAL_ETHEREUM_RPC_URL" \

    cast send "$stake_registry_address" \
        "registerOperatorWithSignature((bytes,bytes32,uint256),address)" \
        "($signature,$salt,$expiry)" "$public_key" \
        --private-key "$private_key" \
        --rpc-url "$LOCAL_ETHEREUM_RPC_URL"
    if [ $? -eq 0 ]; then
        echo "Successfully registered operator $public_key with AVS"
    else
        echo "Error: Failed to register operator with AVS"
        exit 1
    fi
}

setup_operator() {
    local WAVSServiceManagerAddress=$1
    local private_key=$2
    local public_key=$(cast wallet address $private_key)

    DEPLOY_FILE="contracts/deployments/eigenlayer-core/$CHAIN_ID.json"
    STRATEGY_MANAGER_ADDRESS=$(jq -r '.addresses.strategyManager' "$DEPLOY_FILE")
    if [ -z "$STRATEGY_MANAGER_ADDRESS" ]; then
        echo "Error: Failed to read strategyManagerAddress from $DEPLOY_FILE"
        exit 1
    fi
    DELEGATION_MANAGER_ADDRESS=$(jq -r '.addresses.delegation' "$DEPLOY_FILE")
    if [ -z "$DELEGATION_MANAGER_ADDRESS" ]; then
        echo "Error: Failed to read delegationManagerAddress from $DEPLOY_FILE"
        exit 1
    fi


    if [ "$DEPLOY_ENV" = "TESTNET" ]; then
        # TODO: remove this and replace with a check the AVS key has a balance
        # cast s "$public_key" --value 50000000000000000 --private-key "$FUNDED_KEY" -r "$LOCAL_ETHEREUM_RPC_URL" > /dev/null 2>&1
        # if [ $? -ne 0 ]; then
        #     echo "Error: Failed to give operator $index balance"
        #     exit 1
        # fi
        echo ""
    else
        cast rpc anvil_setBalance $public_key 0x10000000000000000000 -r $LOCAL_ETHEREUM_RPC_URL > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "Failed to set balance for operator"
            exit 1
        fi
    fi

    echo "Using LST_CONTRACT_ADDRESS: $LST_CONTRACT_ADDRESS"
    echo "Using LST_STRATEGY_ADDRESS: $LST_STRATEGY_ADDRESS"

    # TODO: is this write? need proper LST addr setup in the .env file
    # TODO: Need to be able to change the amount we stETH stake relative to their balance. TRight now it hands for me?
    AMOUNT=10000 # TODO: make this a value set via cli args / env variables to override
    MINT_FUNCTION="submit(address _referral)"
    cast send "$LST_CONTRACT_ADDRESS" "$MINT_FUNCTION" "$public_key" "0x0000000000000000000000000000000000000000" \
        --private-key "$private_key" \
        --value ${AMOUNT} \
        --rpc-url "$LOCAL_ETHEREUM_RPC_URL" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Failed to mint LST for $ADDRESS"
        exit 1
    fi
    cast send "$LST_CONTRACT_ADDRESS" "approve(address,uint256)" \
        "$STRATEGY_MANAGER_ADDRESS" ${AMOUNT} \
        --private-key "$private_key" \
        --rpc-url "$LOCAL_ETHEREUM_RPC_URL" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Failed to approve LST for $STRATEGY_MANAGER_ADDRESS"
        exit 1
    fi
    cast send "$STRATEGY_MANAGER_ADDRESS" "depositIntoStrategy(address,address,uint256)" \
        "$LST_STRATEGY_ADDRESS" "$LST_CONTRACT_ADDRESS" ${AMOUNT} \
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
    register_operator_with_avs "$private_key" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Failed to register operator $public_key to AVS"
        exit 1
    fi
    echo "Successfully registered operator $public_key to AVS"

}

if [ -z "$1" ]; then
    echo "Error: Pass private AVS Key as first arg"
    exit 1
fi
setup_operator "$WAVSServiceManagerAddress" "$1"
