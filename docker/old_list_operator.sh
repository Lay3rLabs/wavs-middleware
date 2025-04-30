#!/bin/bash

# -x echos all lines for debug
# set -x

set -o errexit -o nounset -o pipefail
command -v shellcheck >/dev/null && shellcheck "$0"

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
# shellcheck source=./helpers.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR"/helpers.sh

# Set up colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print header
echo -e "${GREEN}WAVS Middleware - List Registered Operators${NC}"

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

# Run the forge script
echo -e "\n${GREEN}Running Forge script to list operators...${NC}"
cd /wavs/contracts && \
forge script script/WavsListOperators.s.sol --rpc-url "$LOCAL_ETHEREUM_RPC_URL"

# Exit gracefully
echo -e "\n${GREEN}Done!${NC}"
