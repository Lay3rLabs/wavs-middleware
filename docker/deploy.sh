#!/bin/bash

set -o errexit -o nounset -o pipefail
command -v shellcheck >/dev/null && shellcheck "$0"

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
    if [ -z "${!var_name:-}" ]; then
        echo -e "${RED}Error: $var_name is not set in the environment variables${NC}"
        echo "Please set it in docker/.env file"
        exit 1
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
    RPC_URL="$TESTNET_RPC_URL"
    echo -e "${YELLOW}Deploying to TESTNET at $RPC_URL${NC}"
else
    RPC_URL="http://localhost:8545"
    echo -e "${YELLOW}Deploying to LOCAL at $RPC_URL${NC}"
    
    # Check if anvil is running
    if ! curl -s -X POST -H "Content-Type: application/json" \
             --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' \
             "$RPC_URL" > /dev/null; then
        echo -e "${RED}Error: Could not connect to anvil at $RPC_URL${NC}"
        echo "Please run anvil in another terminal with:"
        echo "anvil --fork-url \$RPC_URL --host 0.0.0.0 --port 8545"
        exit 1
    fi
fi

# Create output directory
mkdir -p ~/.nodes
mkdir -p deployments/wavs-middleware

# Display configuration
echo -e "\n${GREEN}Deployment Configuration:${NC}"
echo "- Environment: $DEPLOY_ENV"
echo "- RPC URL: $RPC_URL"
echo "- Metadata URI: $METADATA_URI"
echo "- LST Strategy: $LST_STRATEGY_ADDRESS"
echo -e "- LST Contract: $LST_CONTRACT_ADDRESS\n"

# Run the forge script
echo -e "${GREEN}Running Forge deployment script...${NC}"
forge script script/WavsDeployment.s.sol:WavsDeployment --rpc-url "$RPC_URL" --private-key "$FUNDED_KEY" --broadcast

# Check if the deployment was successful
if [ $? -ne 0 ]; then
    echo -e "\n${RED}Deployment failed${NC}"
    exit 1
fi

# Copy deployment file to .nodes directory
echo -e "\n${GREEN}Copying deployment file to ~/.nodes/avs_deploy.json${NC}"
CHAIN_ID=$(cast chain-id --rpc-url "$RPC_URL")
if [ -f "deployments/wavs-middleware/$CHAIN_ID.json" ]; then
    cp "deployments/wavs-middleware/$CHAIN_ID.json" ~/.nodes/avs_deploy.json
    echo -e "${GREEN}Deployment successful!${NC}"
    echo "Deployment details saved to:"
    echo "- deployments/wavs-middleware/$CHAIN_ID.json"
    echo "- ~/.nodes/avs_deploy.json"
else
    echo -e "${RED}Error: Deployment file not found${NC}"
    echo "Expected at: deployments/wavs-middleware/$CHAIN_ID.json"
    exit 1
fi

echo -e "\n${GREEN}Done!${NC}"
echo "To view the registered operators, run the list_operators.sh script"
echo "To register a new operator, run the register_operator.sh script"
echo "To set a service URI, run the set_service_uri.sh script" 