#!/bin/bash

# -x echos all lines for debug
# set -x

set -o errexit -o nounset -o pipefail
command -v shellcheck >/dev/null && shellcheck "$0"

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
# shellcheck source=../../helper.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../helper.sh"

# shellcheck source=../foundry_profile.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../foundry_profile.sh"

# Parse command line arguments in key=value format
parse_args "$@"

# Check required parameters with defaults
check_param "DEPLOY_ENV" "${DEPLOY_ENV:-LOCAL}"
check_param "LST_CONTRACT_ADDRESS" "${LST_CONTRACT_ADDRESS:-}"
check_param "LST_STRATEGY_ADDRESS" "${LST_STRATEGY_ADDRESS:-}"
check_param "WAVS_SERVICE_MANAGER_ADDRESS" "${WAVS_SERVICE_MANAGER_ADDRESS:-$(jq -r '.addresses.WavsServiceManager' "$HOME/.nodes/avs_deploy.json")}"
check_param "OPERATOR_KEY" "${OPERATOR_KEY:-}"
check_param "WAVS_DELEGATE_AMOUNT" "${WAVS_DELEGATE_AMOUNT:-$1}"

# Set up environment based on DEPLOY_ENV
setup_environment

# Get allocation delay configuration from allocation manager
echo "Getting allocation delay configuration..."
ALLOCATION_MANAGER_ADDRESS=$(cast call "$WAVS_SERVICE_MANAGER_ADDRESS" "getAllocationManager()(address)" --rpc-url "$RPC_URL")
echo "Allocation Manager Address: $ALLOCATION_MANAGER_ADDRESS"

ALLOCATION_DELAY=$(cast call "$ALLOCATION_MANAGER_ADDRESS" "ALLOCATION_CONFIGURATION_DELAY()(uint32)" --rpc-url "$RPC_URL")
echo "Allocation Delay: $ALLOCATION_DELAY blocks"
# Increase allocation delay by 1 block
ALLOCATION_DELAY=$((ALLOCATION_DELAY + 1))

# Get operator address
OP_ADDR=$(cast wallet address "$OPERATOR_KEY")

# Ensure operator has sufficient balance
ensure_balance "$OP_ADDR"

echo "Operator address: $OP_ADDR"
echo "Delegate amount: $WAVS_DELEGATE_AMOUNT"

cd contracts || handle_error "Failed to change to contracts directory"

# Deposit into strategy
forge script script/eigenlayer/bls/WavsDepositIntoStrategy.s.sol -vvv --rpc-url "$RPC_URL" --private-key "$OPERATOR_KEY" --broadcast || handle_error "Failed to deposit into strategy"

# Wait based on environment
if [[ "$DEPLOY_ENV" == "LOCAL" ]]; then
    echo "Mining $ALLOCATION_DELAY blocks for local transaction confirmation..."
    for ((i=1; i<=ALLOCATION_DELAY; i++)); do 
        cast rpc evm_mine --rpc-url http://localhost:8545
    done
elif [[ "$DEPLOY_ENV" == "TESTNET" ]]; then
    WAIT_TIME=$((12 * ALLOCATION_DELAY))
    echo "Waiting $WAIT_TIME seconds for testnet transaction confirmation..." && sleep "$WAIT_TIME"
fi

# Register operator
forge script script/eigenlayer/bls/WavsRegisterOperator.s.sol -vvv --rpc-url "$RPC_URL" --private-key "$OPERATOR_KEY" --broadcast --slow || handle_error "Failed to register operator"
