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

if [ -z "$WAVS_SERVICE_MANAGER_ADDRESS" ]; then
    echo "Error: WAVS_SERVICE_MANAGER_ADDRESS is not set in the environment variables (tip: grab from .nodes/avs_deploy.json)."
    exit 1
fi

STAKE_REGISTRY_ADDRESS=$(cast call "$WAVS_SERVICE_MANAGER_ADDRESS" "stakeRegistry()(address)" --rpc-url "$LOCAL_ETHEREUM_RPC_URL")

# Function to register operator with AVS using cast commands
register_operator_with_avs() {
    echo "Registering operator with AVS..."
    local private_key=$1
    local address=$(cast wallet address $private_key)

    echo "Registering operator $address with AVS..."

    local avs_directory_address=$(cast call "${WAVS_SERVICE_MANAGER_ADDRESS}" "avsDirectory()" --rpc-url "$LOCAL_ETHEREUM_RPC_URL" | cast parse-bytes32-address)
    if [ -z "$avs_directory_address" ]; then
        echo "Error: Failed to get AVSDirectory from ${WAVS_SERVICE_MANAGER_ADDRESS} avsDirectory()"
        exit 1
    fi
    # Generate a random salt (32 bytes)
    local salt=$(openssl rand -hex 32)

    # Calculate expiry (current time + 1 hour)
    local expiry=$(($(date +%s) + 3600))

    local digest_hash=$(cast call "$avs_directory_address" "calculateOperatorAVSRegistrationDigestHash(address,address,bytes32,uint256)" "$address" "$WAVS_SERVICE_MANAGER_ADDRESS" "$salt" "$expiry" --rpc-url "$LOCAL_ETHEREUM_RPC_URL")
    # Remove 0x prefix from digest hash if present
    digest_hash=${digest_hash#0x}
    # Sign the digest hash with the private key
    local signature=$(cast wallet sign $digest_hash --no-hash --private-key "$private_key")

    local operatorRegistered=$(cast call "$STAKE_REGISTRY_ADDRESS" "operatorRegistered(address)(bool)" "$address" --rpc-url "$LOCAL_ETHEREUM_RPC_URL")
    if [ "$operatorRegistered" = "false" ]; then
        echo "Registering operator with signature..."
        cast send "$STAKE_REGISTRY_ADDRESS" \
            "registerOperatorWithSignature((bytes,bytes32,uint256),address)" \
            "($signature,$salt,$expiry)" "$address" \
            --private-key "$private_key" \
            --rpc-url "$LOCAL_ETHEREUM_RPC_URL" || (echo "Error: Failed to register operator with AVS" && exit 1)
        echo ""
        echo "Successfully registered operator $address with AVS"
    else
        echo "Operator $address is already registered with AVS"
        return 0
    fi
}

setup_operator() {
    local WAVS_SERVICE_MANAGER_ADDRESS=$1
    local private_key=$2
    local address=$(cast wallet address $private_key)
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
        balance=$(cast balance "$address" --rpc-url "$LOCAL_ETHEREUM_RPC_URL") || (echo "Error: Failed to get balance for operator $address" && exit 1)
        if [ "$balance" -eq 0 ]; then
            echo "Error: Funded key ${address} has no balance, you must fund this first with > ${amount}"
            exit 1
        else
            echo "Operator $address already has a balance of $balance"
        fi
    else
        cast rpc anvil_setBalance $address 0x10000000000000000000 -r $LOCAL_ETHEREUM_RPC_URL > /dev/null 2>&1 || (echo "Error: Failed to set balance for operator $address" && exit 1)
    fi

    echo "Using LST_CONTRACT_ADDRESS: $LST_CONTRACT_ADDRESS"
    echo "Using LST_STRATEGY_ADDRESS: $LST_STRATEGY_ADDRESS"

    NUM_DEPOSIT=$(cast call "$STRATEGY_MANAGER_ADDRESS" "stakerStrategyListLength(address)(uint256)" "$address" --rpc-url "$LOCAL_ETHEREUM_RPC_URL")

    # If the operator has deposits, we don't need to do anything
    if [ "$NUM_DEPOSIT" -gt 0 ]; then
        echo "Operator $address already has deposits, skipping LST operations"
    else
        # Check if operator already has LST balance
        LST_BALANCE=$(cast call "$LST_CONTRACT_ADDRESS" "balanceOf(address)(uint256)" "$address" --rpc-url "$LOCAL_ETHEREUM_RPC_URL") || (echo "Error: Failed to get LST balance for operator $address" && exit 1)

        # Only mint LSTs if operator has no balance
        if [ "$LST_BALANCE" -eq 0 ]; then
            echo "Operator $address has no LST balance, minting new tokens"
            cast send "$LST_CONTRACT_ADDRESS" "submit(address _referral)" "$address" "0x0000000000000000000000000000000000000000" \
                --private-key "$private_key" \
                --value "${amount}" \
                --rpc-url "$LOCAL_ETHEREUM_RPC_URL" > /dev/null 2>&1 || (echo "Error: Failed to mint LST for $address" && exit 1)
        else
            echo "Operator $address already has LST balance of $LST_BALANCE"
        fi

        cast send "$LST_CONTRACT_ADDRESS" "approve(address,uint256)" \
            "$STRATEGY_MANAGER_ADDRESS" "${amount}" \
            --private-key "$private_key" \
            --rpc-url "$LOCAL_ETHEREUM_RPC_URL" > /dev/null 2>&1 || (echo "Error: Failed to approve LST for $address" && exit 1)

        # Create a new deposit with the LSTs since we confirmed NUM_DEPOSIT is 0
        echo "Operator $address has no deposits, creating a new deposit"
        cast send "$STRATEGY_MANAGER_ADDRESS" "depositIntoStrategy(address,address,uint256)" \
            "$LST_STRATEGY_ADDRESS" "$LST_CONTRACT_ADDRESS" ${amount} \
            --private-key "$private_key" \
            --rpc-url "$LOCAL_ETHEREUM_RPC_URL" > /dev/null 2>&1 || (echo "Error: Failed to create deposit for $address" && exit 1)
    fi

    # You can not double register an operator. If they are already registered, skip this step.
    isDelegated=`cast call "${DELEGATION_MANAGER_ADDRESS}" "isDelegated(address)(bool)" "${address}" --rpc-url "$LOCAL_ETHEREUM_RPC_URL"`
    if [ "$isDelegated" = "false" ]; then
        cast send "$DELEGATION_MANAGER_ADDRESS" \
            "registerAsOperator(address,uint32,string)" \
            "$address" 0 "foo.bar" \
            --private-key "$private_key" \
            --rpc-url "$LOCAL_ETHEREUM_RPC_URL"  > /dev/null 2>&1 || (echo "Error: Failed to register operator on delegation manager" && exit 1)

        allocationManager=$(cast call "$WAVS_SERVICE_MANAGER_ADDRESS" "allocationManager()" --rpc-url "$LOCAL_ETHEREUM_RPC_URL" | cast parse-bytes32-address)

        # 0x1234 is just arbitrary data which we can input for things like DKG, TEE, etc
        cast s "$allocationManager" \
            "registerForOperatorSets(address,(address,uint32[],bytes))" \
            "$address" \
            "($WAVS_SERVICE_MANAGER_ADDRESS,[1],0x1234)" \
            --private-key "$private_key" \
            --rpc-url "$LOCAL_ETHEREUM_RPC_URL"  > /dev/null 2>&1 || (echo "Error: Failed to register for operator set on allocation manager" && exit 1)
        if [ $? -eq 0 ]; then
            echo "Successfully registered operator $address to operator sets [1]"
        else
            echo "Error: Failed to register operator $address to operator sets"
            exit 1
        fi
    fi

    register_operator_with_avs "$private_key" || ( echo "Error: Failed to register operator with AVS" && exit 1 )
}

if [ -z "$1" ]; then
    echo "Error: Pass private AVS Key as first arg"
    exit 1
fi
if [ -z "$2" ]; then
    echo "Error: Pass amount to deposit as second arg (0.001ether for example)"
    exit 1
fi
setup_operator "$WAVS_SERVICE_MANAGER_ADDRESS" "$1" "$2"
