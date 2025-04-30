#!/bin/bash

set -o errexit -o nounset -o pipefail
command -v shellcheck >/dev/null && shellcheck "$0"

# Set up colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print header
echo -e "${GREEN}WAVS Middleware - Update Operator Stakes${NC}"

# Load environment variables
if [ -f "docker/.env" ]; then
    source docker/.env
fi

# Set up RPC URL based on environment
if [ "${DEPLOY_ENV:-LOCAL}" = "TESTNET" ]; then
    RPC_URL="${TESTNET_RPC_URL:-}"
    echo -e "${YELLOW}Connecting to TESTNET at $RPC_URL${NC}"
else
    RPC_URL=${LOCAL_ETHEREUM_RPC_URL:-"http://localhost:8545"}
    echo -e "${YELLOW}Connecting to LOCAL at $RPC_URL${NC}"
fi

# Check if FUNDED_KEY is set
if [ -z "${FUNDED_KEY:-}" ]; then
    echo -e "${RED}Error: FUNDED_KEY environment variable is not set${NC}"
    exit 1
fi

# Get chain ID
CHAIN_ID=$(cast chain-id --rpc-url "$RPC_URL")
echo -e "Chain ID: ${CHAIN_ID}"

# Try to find deployments file in multiple locations
DEPLOYMENT_FILE=""

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
        echo -e "Found deployment file at: ${DEPLOYMENT_FILE}"
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

# Get stake registry address
STAKE_REGISTRY=$(jq -r '.addresses.stakeRegistry' "$DEPLOYMENT_FILE")
if [ -z "$STAKE_REGISTRY" ] || [ "$STAKE_REGISTRY" = "null" ]; then
    echo -e "${RED}Error: Failed to read stake registry address from $DEPLOYMENT_FILE${NC}"
    echo "File contents:"
    cat "$DEPLOYMENT_FILE" | head -20
    exit 1
fi

echo -e "Stake Registry: ${STAKE_REGISTRY}"

# Define operators to update
OPERATOR_LIST=""
if [ $# -gt 0 ]; then
    for op in "$@"; do
        if [ -z "$OPERATOR_LIST" ]; then
            OPERATOR_LIST="$op"
        else
            OPERATOR_LIST="$OPERATOR_LIST,$op"
        fi
    done
    echo -e "Using specified operators: $OPERATOR_LIST"
else
    echo -e "${RED}Error: No operators specified. Please provide at least one operator address as an argument.${NC}"
    echo -e "Usage: $0 <operator1_address> [operator2_address] [...]"
    echo -e "Example: $0 0x123abc... 0x456def..."
    exit 1
fi

# Export operators for Forge script
export OPERATORS="$OPERATOR_LIST"

# Run Forge script to update stakes
echo -e "\n${GREEN}Running Forge script to update stakes...${NC}"
forge script script/UpdateStakes.s.sol:UpdateStakes --rpc-url "$RPC_URL" --private-key "$FUNDED_KEY" --broadcast

echo -e "\n${GREEN}Done! Run check_all_operators.sh to see updated weights${NC}" 