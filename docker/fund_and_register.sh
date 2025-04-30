#!/bin/bash

set -o errexit -o nounset -o pipefail
command -v shellcheck >/dev/null && shellcheck "$0"

# Set up colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print header
echo -e "${GREEN}WAVS Middleware - Fund and Register Operator${NC}"

# Check if .env file exists
if [ ! -f "docker/.env" ]; then
    echo -e "${RED}Error: docker/.env file does not exist${NC}"
    exit 1
fi

# Source the environment variables
source docker/.env

# Check required environment variables
check_env_var() {
    local var_name="$1"
    if [ -z "${!var_name:-}" ]; then
        echo -e "${RED}Error: $var_name is not set in the environment variables${NC}"
        exit 1
    fi
}

check_env_var "FUNDED_KEY"
check_env_var "LST_CONTRACT_ADDRESS"

# Set up RPC URL based on environment
if [ "$DEPLOY_ENV" = "TESTNET" ]; then
    RPC_URL="$TESTNET_RPC_URL"
    echo -e "${YELLOW}Using TESTNET at $RPC_URL${NC}"
else
    RPC_URL="http://localhost:8545"
    echo -e "${YELLOW}Using LOCAL at $RPC_URL${NC}"
fi

# Amount of stETH to transfer (default 0.1)
AMOUNT=${1:-"0.1"}
echo -e "Using amount: ${AMOUNT} stETH"

# Generate new operator key
echo -e "\n${GREEN}Generating new operator key...${NC}"
OPERATOR_KEY=$(cast wallet new --json | jq -r '.[0].private_key')
OPERATOR_ADDRESS=$(cast wallet addr --private-key "$OPERATOR_KEY")
echo -e "Operator address: ${OPERATOR_ADDRESS}"

# Check funded key balance
echo -e "\n${GREEN}Checking FUNDED_KEY balance...${NC}"
DEPLOYER_ADDRESS=$(cast wallet addr --private-key "$FUNDED_KEY")
echo -e "Deployer address: ${DEPLOYER_ADDRESS}"

echo -e "\n${GREEN}Checking stETH balance...${NC}"
BALANCE_RAW=$(cast call --rpc-url "$RPC_URL" "$LST_CONTRACT_ADDRESS" "balanceOf(address)(uint256)" "$DEPLOYER_ADDRESS" || echo "0")

# Extract just the number part (remove annotations like [3e17])
BALANCE=$(echo "$BALANCE_RAW" | sed -E 's/\s+\[.*\]$//')

# Check if we have any balance
if [ "$BALANCE" = "0" ]; then
    echo -e "${RED}Error: No stETH balance found. Raw response: $BALANCE_RAW${NC}"
    exit 1
fi

# Convert to ETH for display
BALANCE_ETH=$(echo "scale=18; $BALANCE / 10^18" | bc 2>/dev/null || echo "Error")
if [ "$BALANCE_ETH" = "Error" ]; then
    BALANCE_ETH="<calculation error>"
fi

echo -e "stETH balance: ${BALANCE_ETH} (${BALANCE} wei)"

# Convert amount to wei safely
AMOUNT_WEI=$(echo "${AMOUNT} * 10^18" | bc 2>/dev/null | sed 's/\..*$//' || echo "0")
if [ "$AMOUNT_WEI" = "0" ]; then
    echo -e "${RED}Error: Could not convert amount to wei. Please check the input.${NC}"
    exit 1
fi

# Check if balance is sufficient
if (( BALANCE < AMOUNT_WEI )); then
    echo -e "${RED}Error: Insufficient stETH balance. Need at least ${AMOUNT} stETH.${NC}"
    echo -e "Current balance: ${BALANCE_ETH} stETH"
    exit 1
fi

# Transfer stETH from funded key to operator
echo -e "\n${GREEN}Transferring ${AMOUNT} stETH to operator...${NC}"
cast send --rpc-url "$RPC_URL" --private-key "$FUNDED_KEY" "$LST_CONTRACT_ADDRESS" "transfer(address,uint256)(bool)" "$OPERATOR_ADDRESS" "$AMOUNT_WEI"
echo -e "${GREEN}Transfer complete!${NC}"

# Verify operator's balance
echo -e "\n${GREEN}Verifying operator's stETH balance...${NC}"
OP_BALANCE_RAW=$(cast call --rpc-url "$RPC_URL" "$LST_CONTRACT_ADDRESS" "balanceOf(address)(uint256)" "$OPERATOR_ADDRESS" || echo "0")
OP_BALANCE=$(echo "$OP_BALANCE_RAW" | sed -E 's/\s+\[.*\]$//')
OP_BALANCE_ETH=$(echo "scale=18; $OP_BALANCE / 10^18" | bc 2>/dev/null || echo "Error")
if [ "$OP_BALANCE_ETH" = "Error" ]; then
    OP_BALANCE_ETH="<calculation error>"
fi
echo -e "Operator stETH balance: ${OP_BALANCE_ETH} (${OP_BALANCE} wei)"

# Now register the operator
echo -e "\n${GREEN}Registering operator...${NC}"
docker run --rm --network host --env-file docker/.env -v ./deployments:/wavs/deployments -v ./.nodes:/root/.nodes --entrypoint /wavs/docker/register_operator.sh wavs-middleware "$OPERATOR_KEY"

echo -e "\n${GREEN}Process complete!${NC}"
echo -e "Operator address: ${OPERATOR_ADDRESS}"
echo -e "Operator key: ${OPERATOR_KEY}"
echo -e "Please save the operator key securely."

# View the list of operators
echo -e "\n${GREEN}Checking registered operators...${NC}"
docker run --rm --network host --env-file docker/.env -v ./deployments:/wavs/deployments -v ./.nodes:/root/.nodes --entrypoint /wavs/docker/list_operators.sh wavs-middleware 