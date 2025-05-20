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

if [ -z "$WAVSServiceManagerAddress" ]; then
    echo "Error: WAVSServiceManagerAddress is not set in the environment variables (tip: grab from .nodes/avs_deploy.json)."
    exit 1
fi
if [ -z "$StakeRegistryAddress" ]; then
    echo "Error: StakeRegistryAddress is not set in the environment variables (tip: grab from .nodes/avs_deploy.json)."
    exit 1
fi

# Function to register operator with AVS using cast commands
register_operator_with_avs() {
    echo "Registering operator with AVS..."
    local private_key=$1
    local public_key=$(cast wallet address $private_key)

    echo "Registering operator $public_key with AVS..."

    local avs_directory_address=$(cast call "${WAVSServiceManagerAddress}" "avsDirectory()" --rpc-url "$LOCAL_ETHEREUM_RPC_URL" | cast parse-bytes32-address)
    if [ -z "$avs_directory_address" ]; then
        echo "Error: Failed to get AVSDirectory from ${WAVSServiceManagerAddress} avsDirectory()"
        exit 1
    fi
    # Generate a random salt (32 bytes)
    local salt=$(openssl rand -hex 32)

    # Calculate expiry (current time + 1 hour)
    local expiry=$(($(date +%s) + 3600))

    local digest_hash=$(cast call "$avs_directory_address" "calculateOperatorAVSRegistrationDigestHash(address,address,bytes32,uint256)" "$public_key" "$WAVSServiceManagerAddress" "$salt" "$expiry" --rpc-url "$LOCAL_ETHEREUM_RPC_URL")
    # Remove 0x prefix from digest hash if present
    digest_hash=${digest_hash#0x}
    # Sign the digest hash with the private key
    local signature=$(cast wallet sign $digest_hash --no-hash --private-key "$private_key")

    local operatorRegistered=$(cast call "$StakeRegistryAddress" "operatorRegistered(address)(bool)" "$public_key" --rpc-url "$LOCAL_ETHEREUM_RPC_URL")
    if [ "$operatorRegistered" = "false" ]; then
        # Register the operator with the signature
        echo "Registering operator with signature..."
        cast c --trace "$StakeRegistryAddress" \
            "registerOperatorWithSignature((bytes,bytes32,uint256),address)" \
            "($signature,$salt,$expiry)" "$public_key" \
            --private-key "$private_key" \
            --rpc-url "$LOCAL_ETHEREUM_RPC_URL" \

        cast send "$StakeRegistryAddress" \
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
    else
        echo "Operator $public_key is already registered with AVS"
        return 0
    fi
}

setup_operator() {
    local WAVSServiceManagerAddress=$1
    local private_key=$2
    local public_key=$(cast wallet address $private_key)
    local amount=$3

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
        # Balance check the operator registering. if they have funds, skip funding
        balance=$(cast balance "$public_key" --rpc-url "$LOCAL_ETHEREUM_RPC_URL")
        if [ $? -ne 0 ]; then
            echo "Error: Failed to get balance for operator $public_key"
            exit 1
        fi
        if [ "$balance" -eq 0 ]; then
            # Validate the PRIVATE_KEY address has a balance on testnet (i.e. it's not a default anvil private key)
            PRIVATE_KEY_balance=$(cast balance `cast wallet address "$PRIVATE_KEY"` --rpc-url "$LOCAL_ETHEREUM_RPC_URL")
            if [ "$PRIVATE_KEY_balance" -eq 0 ]; then
                echo "Error: Funded key `cast wallet address $PRIVATE_KEY` has no balance, you must fund this first "
                exit 1
            fi


            cast s "$public_key" --value ${amount} --private-key "$PRIVATE_KEY" -r "$LOCAL_ETHEREUM_RPC_URL" > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                echo "Error: Failed to give operator $index balance"
                exit 1
            fi
            echo "Funded operator $public_key with ${amount}"
        else
            echo "Operator $public_key already has a balance of $balance"
        fi
    else
        cast rpc anvil_setBalance $public_key 0x10000000000000000000 -r $LOCAL_ETHEREUM_RPC_URL > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "Failed to set balance for operator"
            exit 1
        fi
    fi

    echo "Using LST_CONTRACT_ADDRESS: $LST_CONTRACT_ADDRESS"
    echo "Using LST_STRATEGY_ADDRESS: $LST_STRATEGY_ADDRESS"

    MINT_FUNCTION="submit(address _referral)"
    cast send "$LST_CONTRACT_ADDRESS" "$MINT_FUNCTION" "$public_key" "0x0000000000000000000000000000000000000000" \
        --private-key "$private_key" \
        --value ${amount} \
        --rpc-url "$LOCAL_ETHEREUM_RPC_URL" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Failed to mint LST for $ADDRESS"
        exit 1
    fi
    cast send "$LST_CONTRACT_ADDRESS" "approve(address,uint256)" \
        "$STRATEGY_MANAGER_ADDRESS" ${amount} \
        --private-key "$private_key" \
        --rpc-url "$LOCAL_ETHEREUM_RPC_URL" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Failed to approve LST for $STRATEGY_MANAGER_ADDRESS"
        exit 1
    fi
    cast send "$STRATEGY_MANAGER_ADDRESS" "depositIntoStrategy(address,address,uint256)" \
        "$LST_STRATEGY_ADDRESS" "$LST_CONTRACT_ADDRESS" ${amount} \
        --private-key "$private_key" \
        --rpc-url "$LOCAL_ETHEREUM_RPC_URL" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Failed to deposit into strategy for $LST_STRATEGY_ADDRESS"
        exit 1
    fi

    allocationManager=$(cast call "$WAVSServiceManagerAddress" "allocationManager()" --rpc-url "$LOCAL_ETHEREUM_RPC_URL" | cast parse-bytes32-address)

    # You can not double register an operator. If they are already registered, skip this step.
    isDelegated=`cast call "${DELEGATION_MANAGER_ADDRESS}" "isDelegated(address)(bool)" "${public_key}" --rpc-url "$LOCAL_ETHEREUM_RPC_URL"`
    if [ "$isDelegated" = "false" ]; then
        cast send "$DELEGATION_MANAGER_ADDRESS" \
            "registerAsOperator(address,uint32,string)" \
            "$public_key" 0 "foo.bar" \
            --private-key "$private_key" \
            --rpc-url "$LOCAL_ETHEREUM_RPC_URL"  > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo "Error: Failed to register as operator for $DELEGATION_MANAGER_ADDRESS"
            exit 1
        fi

        # 0x1234 is just arbitrary data which we can input for things like DKG, TEE, etc
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
    fi

    register_operator_with_avs "$private_key"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to register operator $public_key to AVS"
        exit 1
    fi

}

if [ -z "$1" ]; then
    echo "Error: Pass private AVS Key as first arg"
    exit 1
fi
if [ -z "$2" ]; then
    echo "Error: Pass amount to deposit as second arg (0.001ether for example)"
    exit 1
fi
setup_operator "$WAVSServiceManagerAddress" "$1" "$2"
