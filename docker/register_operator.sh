#!/bin/bash

set -o errexit -o nounset -o pipefail
command -v shellcheck >/dev/null && shellcheck "$0"

# Set up colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
# shellcheck source=./helpers.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR"/helpers.sh

# Print header
echo -e "${GREEN}WAVS Middleware - Register Operator${NC}"

# Check arguments
if [ -z "$1" ]; then
    echo -e "${RED}Error: Pass private AVS Key as first arg${NC}"
    exit 1
fi

OPERATOR_KEY="$1"
echo -e "Using operator private key to register"

# Set up RPC URL based on environment
if [ "$DEPLOY_ENV" = "TESTNET" ]; then
    LOCAL_ETHEREUM_RPC_URL="$TESTNET_RPC_URL"
    echo -e "${YELLOW}Connecting to TESTNET at $LOCAL_ETHEREUM_RPC_URL${NC}"
else
    LOCAL_ETHEREUM_RPC_URL=${LOCAL_ETHEREUM_RPC_URL:-"http://localhost:8545"}
    echo -e "${YELLOW}Connecting to LOCAL at $LOCAL_ETHEREUM_RPC_URL${NC}"
    
    # Wait for Ethereum node
    wait_for_ethereum
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

# Get service manager address
WAVSServiceManagerAddress=$(cat /root/.nodes/avs_deploy.json | jq -r '.addresses.WavsServiceManager')
if [ -z "$WAVSServiceManagerAddress" ]; then
    echo -e "${RED}Error: Failed to read WavsServiceManager from /root/.nodes/avs_deploy.json${NC}"
    exit 1
fi

# Display configuration
echo -e "\n${GREEN}Registration Configuration:${NC}"
echo "- Environment: $DEPLOY_ENV"
echo "- RPC URL: $LOCAL_ETHEREUM_RPC_URL"
echo "- LST Strategy: $LST_STRATEGY_ADDRESS"
echo -e "- LST Contract: $LST_CONTRACT_ADDRESS\n"

# Export needed variables for the script
export OPERATOR_KEY

# Run the forge script in the Docker context
cd /wavs/contracts && \
forge script script/WavsRegisterOperator.s.sol "$OPERATOR_KEY" \
    --rpc-url "$LOCAL_ETHEREUM_RPC_URL" \
    --private-key "$FUNDED_KEY" \
    --broadcast

# Check if the registration was successful
if [ $? -ne 0 ]; then
    echo -e "\n${RED}Failed to register operator${NC}"
    exit 1
fi

echo -e "\n${GREEN}Operator registration completed successfully!${NC}" 