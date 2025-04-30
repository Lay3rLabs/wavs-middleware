#!/bin/bash

set -o errexit -o nounset -o pipefail
command -v shellcheck >/dev/null && shellcheck "$0"

# Set up colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print header
echo -e "${GREEN}WAVS Middleware - Check Specific Operator${NC}"

# Check arguments
if [ -z "$1" ]; then
    echo -e "${RED}Error: Pass operator address as first arg${NC}"
    exit 1
fi

OPERATOR_ADDRESS="$1"
echo -e "Checking operator: ${OPERATOR_ADDRESS}"

# Load environment variables if .env file exists
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

# Get chain ID
CHAIN_ID=$(cast chain-id --rpc-url "$RPC_URL")
echo -e "Chain ID: ${CHAIN_ID}"

# Try to find deployments file in multiple locations
DEPLOYMENT_FILE=""

# Check local file first (for running outside Docker)
if [ -f "./deployments/wavs-middleware/${CHAIN_ID}.json" ]; then
    DEPLOYMENT_FILE="./deployments/wavs-middleware/${CHAIN_ID}.json"
    echo -e "Found deployment file at: ${DEPLOYMENT_FILE}"
elif [ -f "./.nodes/avs_deploy.json" ]; then
    DEPLOYMENT_FILE="./.nodes/avs_deploy.json"
    echo -e "Found deployment file at: ${DEPLOYMENT_FILE}"
elif [ -f "${HOME}/.nodes/avs_deploy.json" ]; then
    DEPLOYMENT_FILE="${HOME}/.nodes/avs_deploy.json"
    echo -e "Found deployment file at: ${DEPLOYMENT_FILE}"
else
    echo -e "${RED}Error: Could not find deployment file in any of the following locations:${NC}"
    echo -e "- ./deployments/wavs-middleware/${CHAIN_ID}.json"
    echo -e "- ./.nodes/avs_deploy.json"
    echo -e "- ~/.nodes/avs_deploy.json"
    echo -e "Please run the deployment script first"
    exit 1
fi

# Get stake registry address
STAKE_REGISTRY=$(jq -r '.addresses.stakeRegistry' "$DEPLOYMENT_FILE")
if [ -z "$STAKE_REGISTRY" ] || [ "$STAKE_REGISTRY" = "null" ]; then
    echo -e "${RED}Error: Could not find stake registry address in deployment file${NC}"
    exit 1
fi

echo -e "Stake Registry: ${STAKE_REGISTRY}"

# Check operator weight
echo -e "\n${GREEN}Checking operator weight...${NC}"
WEIGHT=$(cast call --rpc-url "$RPC_URL" "$STAKE_REGISTRY" "getOperatorWeight(address)(uint256)" "$OPERATOR_ADDRESS")
echo -e "Operator ${OPERATOR_ADDRESS} weight: ${WEIGHT}"

# Convert to ETH for readability if possible
if [[ "$WEIGHT" =~ ^[0-9]+$ ]]; then
    WEIGHT_ETH=$(echo "scale=18; $WEIGHT / 10^18" | bc 2>/dev/null || echo "Error")
    if [ "$WEIGHT_ETH" != "Error" ]; then
        echo -e "Weight in ETH: ${WEIGHT_ETH}"
    fi
fi

# Check if the weight is greater than minimum (1)
if [[ "$WEIGHT" =~ ^[0-9]+$ ]] && [ "$WEIGHT" -gt 0 ]; then
    echo -e "${GREEN}Operator is successfully registered with non-zero weight!${NC}"
else
    echo -e "${YELLOW}Operator is registered but has zero weight.${NC}"
    echo -e "This is likely because the operator has no LST tokens staked."
fi

echo -e "\n${GREEN}Done!${NC}" 