#!/bin/bash

set -o errexit -o nounset -o pipefail
command -v shellcheck >/dev/null && shellcheck "$0"

SCRIPT_DIR="$(realpath "$(dirname "$0")")"

# Set up colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print header
echo -e "${GREEN}WAVS Middleware - Set Service URI${NC}"

# Check arguments
if [ -z "$1" ]; then
    echo -e "${RED}Error: Pass SERVICE_URI as first arg${NC}"
    exit 1
fi
SERVICE_URI="$1"
echo -e "Setting Service URI to: ${YELLOW}$SERVICE_URI${NC}"

# Set up RPC URL based on environment
if [ "$DEPLOY_ENV" = "TESTNET" ]; then
    LOCAL_ETHEREUM_RPC_URL="$TESTNET_RPC_URL"
    echo -e "${YELLOW}Connecting to TESTNET at $LOCAL_ETHEREUM_RPC_URL${NC}"
else
    LOCAL_ETHEREUM_RPC_URL=${LOCAL_ETHEREUM_RPC_URL:-"http://localhost:8545"}
    echo -e "${YELLOW}Connecting to LOCAL at $LOCAL_ETHEREUM_RPC_URL${NC}"
fi

# Read the deployer private key from file
if [ -f "/root/.nodes/deployer" ]; then
    deployer_private_key=$(cat "/root/.nodes/deployer")
    echo "Read deployer key from file."
    deployer_public_key=$(cast wallet address "$deployer_private_key")
    echo "Deployer address: $deployer_public_key"
else
    echo -e "${RED}Error: Deployer key file not found at /root/.nodes/deployer${NC}"
    exit 1
fi

# Check for service manager address
SERVICE_MANAGER_ADDRESS=$(jq -r '.addresses.WavsServiceManager' /root/.nodes/avs_deploy.json)
if [ -z "$SERVICE_MANAGER_ADDRESS" ] || [ "$SERVICE_MANAGER_ADDRESS" = "null" ]; then
    echo -e "${RED}Error: Failed to read WavsServiceManager from /root/.nodes/avs_deploy.json${NC}"
    exit 1
fi

# Run the forge script
echo -e "\n${GREEN}Running Forge script to set service URI...${NC}"
# Export the SERVICE_URI as an environment variable for the script
export SERVICE_URI
forge script script/WavsSetServiceURI.s.sol:WavsSetServiceURI \
    --rpc-url "$LOCAL_ETHEREUM_RPC_URL" \
    --private-key "$deployer_private_key" \
    --broadcast

# Check if the update was successful
if [ $? -ne 0 ]; then
    echo -e "\n${RED}Failed to set service URI${NC}"
    exit 1
fi

echo -e "\n${GREEN}Service URI updated successfully!${NC}" 