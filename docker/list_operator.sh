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

if [ -z "$STAKE_REGISTRY_ADDRESS" ]; then
    echo "Error: STAKE_REGISTRY_ADDRESS is not set in the environment variables (tip: grab from .nodes/avs_deploy.json)."
    exit 1
fi

echo "=== ECDSA Stake Registry Status ==="
echo "Contract Address: $STAKE_REGISTRY_ADDRESS"

# Get total weight and threshold
echo -e "\n=== Quorum Information ==="
TOTAL_WEIGHT=$(cast call "$STAKE_REGISTRY_ADDRESS" "getLastCheckpointTotalWeight()(uint256)" --rpc-url "$LOCAL_ETHEREUM_RPC_URL")
THRESHOLD_WEIGHT=$(cast call "$STAKE_REGISTRY_ADDRESS" "getLastCheckpointThresholdWeight()(uint256)" --rpc-url "$LOCAL_ETHEREUM_RPC_URL")
echo "Total Weight: $TOTAL_WEIGHT"
echo "Threshold Weight: $THRESHOLD_WEIGHT"

# Get current block height and calculate range
LATEST_BLOCK=$(cast block-number --rpc-url "$LOCAL_ETHEREUM_RPC_URL")
FROM_BLOCK=$((LATEST_BLOCK - 900))

# Get all OperatorRegistered events
echo -e "\n=== Registered Operators ==="
echo "Querying events from block $FROM_BLOCK to $LATEST_BLOCK"
OPERATOR_EVENTS=$(cast logs --address "$STAKE_REGISTRY_ADDRESS" --from-block "$FROM_BLOCK" --to-block latest "OperatorRegistered(address, address)" --rpc-url "$LOCAL_ETHEREUM_RPC_URL")

if [ -z "$OPERATOR_EVENTS" ]; then
    echo "No OperatorRegistered events found in the specified block range."
    exit 1
fi


# It is the second line after topics,
# and looks like 0x0000000000000000000000003464592915269a1dbdd65b8e3452011e43d50c59
RAW_OPS=$(echo "$OPERATOR_EVENTS" | grep -A2 'topics:' | grep '0x00000000000000')

DEBUG=${DEBUG:-0}
if [ "$DEBUG" -eq 1 ]; then
    echo "Parsing $OPERATOR_EVENTS"
    echo "** matched topics **"
    echo $RAW_OPS
fi

# Convert events to operator addresses and store in array
declare -a OPERATORS
while IFS= read -r line; do
    # Extract the address from the event log (it's the last 40 hex characters)
    OPERATOR="0x${line: -40}"
    OPERATORS+=("$OPERATOR")
    echo "Found operator: $OPERATOR"
done <<< "$RAW_OPS"

# Query weight for each operator
echo -e "\n=== Operator Weights ==="
for OPERATOR in "${OPERATORS[@]}"; do
    WEIGHT=$(cast call "$STAKE_REGISTRY_ADDRESS" "getOperatorWeight(address)(uint256)" "$OPERATOR" --rpc-url "$LOCAL_ETHEREUM_RPC_URL")
    echo "Operator $OPERATOR weight: $WEIGHT"
done

echo
