#!/bin/bash

set -o errexit -o nounset -o pipefail
command -v shellcheck >/dev/null && shellcheck "$0"

# Set up colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Run the forge script
echo -e "\n${GREEN}Running Forge script to list operators...${NC}"
forge script contracts/script/WavsListOperators.s.sol --rpc-url "$RPC_URL"

# Exit gracefully
echo -e "\n${GREEN}Done!${NC}" 