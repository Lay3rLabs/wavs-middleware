#!/bin/bash

set -o errexit -o nounset -o pipefail
command -v shellcheck >/dev/null && shellcheck "$0"

# Set up colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(realpath "$(dirname "$0")")"

# Print header
echo -e "${GREEN}WAVS Middleware - Register Operator${NC}"

# Check arguments
if [ -z "$1" ]; then
    echo -e "${RED}Error: Pass private AVS Key as first arg${NC}"
    exit 1
fi

OPERATOR_KEY="$1"
echo -e "Using operator private key to register"

# Check for optional amount parameter - default to 0.15 stETH
STAKE_AMOUNT=${2:-"0.15"}
echo -e "Using stake amount: $STAKE_AMOUNT stETH"

# Set up RPC URL based on environment
if [ "$DEPLOY_ENV" = "TESTNET" ]; then
    LOCAL_ETHEREUM_RPC_URL="$TESTNET_RPC_URL"
    echo -e "${YELLOW}Connecting to TESTNET at $LOCAL_ETHEREUM_RPC_URL${NC}"
else
    LOCAL_ETHEREUM_RPC_URL=${LOCAL_ETHEREUM_RPC_URL:-"http://localhost:8545"}
    echo -e "${YELLOW}Connecting to LOCAL at $LOCAL_ETHEREUM_RPC_URL${NC}"
fi

# Check required environment variables
check_env_var() {
    local var_name="$1"
    local var_value="${!var_name:-}"
    if [ -z "$var_value" ]; then
        echo -e "${RED}Error: $var_name is not set in the environment variables${NC}"
        exit 1
    fi
}

check_env_var "FUNDED_KEY"
check_env_var "LST_STRATEGY_ADDRESS"
check_env_var "LST_CONTRACT_ADDRESS"

# Look for deployment file in various locations
DEPLOYMENT_FILE=""
CHAIN_ID=$(cast chain-id --rpc-url "$LOCAL_ETHEREUM_RPC_URL")
echo -e "Chain ID: $CHAIN_ID"

# Define possible paths
PATHS=(
    "/root/.nodes/avs_deploy.json"
    "${HOME}/.nodes/avs_deploy.json"
    "./deployments/wavs-middleware/${CHAIN_ID}.json"
    "$(realpath ./deployments/wavs-middleware/${CHAIN_ID}.json)"
)

# Try each path
for path in "${PATHS[@]}"; do
    if [ -f "$path" ]; then
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

# Get service manager address
WAVSServiceManagerAddress=$(jq -r '.addresses.WavsServiceManager' "$DEPLOYMENT_FILE")
if [ -z "$WAVSServiceManagerAddress" ] || [ "$WAVSServiceManagerAddress" = "null" ]; then
    echo -e "${RED}Error: Failed to read WavsServiceManager from $DEPLOYMENT_FILE${NC}"
    echo "File contents:"
    cat "$DEPLOYMENT_FILE" | head -20
    exit 1
fi

echo -e "WavsServiceManager: $WAVSServiceManagerAddress"

# Display configuration
echo -e "\n${GREEN}Registration Configuration:${NC}"
echo "- Environment: $DEPLOY_ENV"
echo "- RPC URL: $LOCAL_ETHEREUM_RPC_URL"
echo "- LST Strategy: $LST_STRATEGY_ADDRESS"
echo "- LST Contract: $LST_CONTRACT_ADDRESS"
echo -e "- Stake Amount: $STAKE_AMOUNT stETH\n"

# Export needed variables for the script
export OPERATOR_KEY
export STAKE_AMOUNT

# Run the forge script in the Docker context
forge script script/RegisterOperator.s.sol:RegisterOperator "$OPERATOR_KEY" "$STAKE_AMOUNT" \
    --rpc-url "$LOCAL_ETHEREUM_RPC_URL" \
    --private-key "$FUNDED_KEY" \
    --broadcast

# Check if the registration was successful
if [ $? -ne 0 ]; then
    echo -e "\n${RED}Failed to register operator${NC}"
    exit 1
fi

echo -e "\n${GREEN}Operator registration completed successfully!${NC}" 