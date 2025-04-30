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

# Look for deployment file in various locations
DEPLOYMENT_FILE=""
CHAIN_ID=$(cast chain-id --rpc-url "$LOCAL_ETHEREUM_RPC_URL")
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

# Read the deployer private key from file
DEPLOYER_KEY_FILE=""
POSSIBLE_KEY_PATHS=(
    "/root/.nodes/deployer"
    "${HOME}/.nodes/deployer"
    "./deployments/deployer_key.txt"
)

for path in "${POSSIBLE_KEY_PATHS[@]}"; do
    if [ -f "$path" ]; then
        DEPLOYER_KEY_FILE="$path"
        echo -e "Found deployer key file at: $DEPLOYER_KEY_FILE"
        break
    fi
done

if [ -z "$DEPLOYER_KEY_FILE" ]; then
    # If we can't find a key file, use the FUNDED_KEY from environment
    if [ -n "${FUNDED_KEY:-}" ]; then
        echo -e "Using FUNDED_KEY from environment as deployer key"
        deployer_private_key="$FUNDED_KEY"
    else
        echo -e "${RED}Error: Could not find deployer key file and FUNDED_KEY is not set${NC}"
        exit 1
    fi
else
    deployer_private_key=$(cat "$DEPLOYER_KEY_FILE")
    echo "Read deployer key from file: $DEPLOYER_KEY_FILE"
fi

deployer_public_key=$(cast wallet address "$deployer_private_key")
echo "Deployer address: $deployer_public_key"

# Check for service manager address
SERVICE_MANAGER_ADDRESS=$(jq -r '.addresses.WavsServiceManager' "$DEPLOYMENT_FILE")
if [ -z "$SERVICE_MANAGER_ADDRESS" ] || [ "$SERVICE_MANAGER_ADDRESS" = "null" ]; then
    echo -e "${RED}Error: Failed to read WavsServiceManager from $DEPLOYMENT_FILE${NC}"
    echo "File contents:"
    cat "$DEPLOYMENT_FILE" | head -20
    exit 1
fi

echo -e "WavsServiceManager: $SERVICE_MANAGER_ADDRESS"

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