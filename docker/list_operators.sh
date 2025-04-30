#!/bin/bash

set -o errexit -o nounset -o pipefail
command -v shellcheck >/dev/null && shellcheck "$0"

# Set up colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print header
echo -e "${GREEN}WAVS Middleware - List Registered Operators${NC}"

# Check if .env file exists
if [ ! -f "docker/.env" ]; then
    echo -e "Warning: docker/.env file does not exist, using default RPC URL"
    export LOCAL_ETHEREUM_RPC_URL="http://localhost:8545"
else
    # Source the environment variables
    source docker/.env
fi

# Set up RPC URL based on environment
if [ "${DEPLOY_ENV:-LOCAL}" = "TESTNET" ]; then
    if [ -z "${TESTNET_RPC_URL:-}" ]; then
        echo "Error: TESTNET_RPC_URL environment variable is not set"
        exit 1
    fi
    RPC_URL="$TESTNET_RPC_URL"
    echo -e "${YELLOW}Connecting to TESTNET at $RPC_URL${NC}"
else
    RPC_URL=${LOCAL_ETHEREUM_RPC_URL:-"http://localhost:8545"}
    echo -e "${YELLOW}Connecting to LOCAL at $RPC_URL${NC}"
fi

# Check for operator argument - if provided, we'll check specific operators
OPERATOR_ARGS=""
if [ $# -gt 0 ]; then
    echo -e "${GREEN}Checking specific operators:${NC}"
    for operator in "$@"; do
        echo "- $operator"
        OPERATOR_ARGS="$OPERATOR_ARGS $operator"
    done
fi

# Look for deployment file in various locations
DEPLOYMENT_FILE=""
CHAIN_ID=$(cast chain-id --rpc-url "$RPC_URL")
echo -e "Chain ID: $CHAIN_ID"

# Define possible paths
PATHS=(
    "/root/.nodes/avs_deploy.json"
    "${HOME}/.nodes/avs_deploy.json"
    "./deployments/wavs-middleware/${CHAIN_ID}.json"
    "$(realpath ./deployments/wavs-middleware/${CHAIN_ID}.json 2>/dev/null || echo '')"
)

# Try each path
for path in "${PATHS[@]}"; do
    if [ -n "$path" ] && [ -f "$path" ]; then
        DEPLOYMENT_FILE="$path"
        echo -e "Found deployment file at: $DEPLOYMENT_FILE"
        break
    fi
done

if [ -z "$DEPLOYMENT_FILE" ]; then
    echo -e "${RED}Error: Could not find deployment file in any of these locations:${NC}"
    for path in "${PATHS[@]}"; do
        echo "- $path"
    done
    echo -e "Please run the deployment script first"
    exit 1
fi

# Get stake registry address for command-line checking if needed
STAKE_REGISTRY=$(jq -r '.addresses.stakeRegistry' "$DEPLOYMENT_FILE")
if [ -z "$STAKE_REGISTRY" ] || [ "$STAKE_REGISTRY" = "null" ]; then
    echo -e "${RED}Error: Failed to read stake registry address from $DEPLOYMENT_FILE${NC}"
    echo "File contents:"
    cat "$DEPLOYMENT_FILE" | head -20
    exit 1
fi

echo -e "Stake Registry: $STAKE_REGISTRY"

# If we have specific operators to check, use our direct checking script
if [ -n "$OPERATOR_ARGS" ]; then
    echo -e "\n${GREEN}Checking operator weights directly...${NC}"
    for operator in $OPERATOR_ARGS; do
        WEIGHT=$(cast call --rpc-url "$RPC_URL" "$STAKE_REGISTRY" "getOperatorWeight(address)(uint256)" "$operator")
        echo -e "Operator ${operator} weight: ${WEIGHT}"
        
        # Convert to ETH for readability if possible
        if [[ "$WEIGHT" =~ ^[0-9]+$ ]]; then
            WEIGHT_ETH=$(echo "scale=18; $WEIGHT / 10^18" | bc 2>/dev/null || echo "Error")
            if [ "$WEIGHT_ETH" != "Error" ]; then
                echo -e "Weight in ETH: ${WEIGHT_ETH}"
            fi
        fi
        
        echo ""
    done
else
    # Run the forge script for full listing
    echo -e "\n${GREEN}Running Forge script to list operators...${NC}"
    forge script script/ListOperators.s.sol:ListOperators --rpc-url "$RPC_URL"
fi

# Exit gracefully
echo -e "\n${GREEN}Done!${NC}" 