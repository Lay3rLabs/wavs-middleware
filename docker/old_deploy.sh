#!/bin/bash

set -o errexit -o nounset -o pipefail
command -v shellcheck >/dev/null && shellcheck "$0"

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
# shellcheck source=./helpers.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR"/helpers.sh

# Set up colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print header
echo -e "${GREEN}WAVS Middleware Deployment${NC}"
echo -e "Running Forge deployment script...\n"

# Check if .env file exists
if [ ! -f "docker/.env" ]; then
    echo -e "${RED}Error: docker/.env file does not exist${NC}"
    echo -e "Please copy docker/env.example to docker/.env and edit it with your configuration"
    exit 1
fi

# Source the environment variables
source docker/.env

# Check required environment variables
check_env_var() {
    local var_name="$1"
    local var_value="${!var_name:-}"
    if [ -z "$var_value" ]; then
        handle_error "$var_name is not set in the environment variables"
    fi
}

check_env_var "FUNDED_KEY"
check_env_var "METADATA_URI"
check_env_var "DEPLOY_ENV"
check_env_var "LST_STRATEGY_ADDRESS"
check_env_var "LST_CONTRACT_ADDRESS"

# Set up RPC URL based on environment
if [ "$DEPLOY_ENV" = "TESTNET" ]; then
    check_env_var "TESTNET_RPC_URL"
    LOCAL_ETHEREUM_RPC_URL="$TESTNET_RPC_URL"
    echo -e "${YELLOW}Deploying to TESTNET at $LOCAL_ETHEREUM_RPC_URL${NC}"
else
    LOCAL_ETHEREUM_RPC_URL=${LOCAL_ETHEREUM_RPC_URL:-"http://localhost:8545"}
    echo -e "${YELLOW}Deploying to LOCAL at $LOCAL_ETHEREUM_RPC_URL${NC}"
    
    # Wait for Ethereum node
    wait_for_ethereum
fi

# Create output directory
mkdir -p /root/.nodes

# Write the deployer key to file
echo "$FUNDED_KEY" > /root/.nodes/deployer
deployer_public_key=$(cast wallet address "$FUNDED_KEY")
echo "Deployer address: $deployer_public_key configured for $DEPLOY_ENV environment"

# Display configuration
echo -e "\n${GREEN}Deployment Configuration:${NC}"
echo "- Environment: $DEPLOY_ENV"
echo "- RPC URL: $LOCAL_ETHEREUM_RPC_URL"
echo "- Metadata URI: $METADATA_URI"
echo "- LST Strategy: $LST_STRATEGY_ADDRESS"
echo -e "- LST Contract: $LST_CONTRACT_ADDRESS\n"

# Run the forge script
echo -e "${GREEN}Running Forge deployment script...${NC}"
cd /wavs/contracts && \
forge script script/WavsDeployment.s.sol \
    --rpc-url "$LOCAL_ETHEREUM_RPC_URL" \
    --private-key "$FUNDED_KEY" \
    --broadcast \
    --slow

# Check if the deployment was successful
if [ $? -ne 0 ]; then
    echo -e "\n${RED}Deployment failed${NC}"
    exit 1
fi

# Copy deployment file to .nodes directory
echo -e "\n${GREEN}Copying deployment file to /root/.nodes/avs_deploy.json${NC}"
CHAIN_ID=$(cast chain-id --rpc-url "$LOCAL_ETHEREUM_RPC_URL")
if [ -f "/wavs/contracts/deployments/wavs-middleware/$CHAIN_ID.json" ]; then
    cp "/wavs/contracts/deployments/wavs-middleware/$CHAIN_ID.json" /root/.nodes/avs_deploy.json
    echo -e "${GREEN}Deployment successful!${NC}"
    echo "Deployment details saved to:"
    echo "- /wavs/contracts/deployments/wavs-middleware/$CHAIN_ID.json"
    echo "- /root/.nodes/avs_deploy.json"
else
    echo -e "${RED}Error: Deployment file not found${NC}"
    echo "Expected at: /wavs/contracts/deployments/wavs-middleware/$CHAIN_ID.json"
    exit 1
fi

echo -e "\n${GREEN}Done!${NC}"
echo "To view the registered operators, run the list_operator.sh script"
echo "To register a new operator, run the register.sh script"
echo "To set a service URI, run the set_service_uri.sh script" 