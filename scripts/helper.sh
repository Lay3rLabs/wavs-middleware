#!/bin/bash
# Global helper functions for WAVS middleware scripts
# This file should be sourced by other scripts, not run directly

set -o errexit -o nounset -o pipefail

export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

# Parse command line arguments in key=value format
# Usage: parse_args "$@"
# Sets variables based on key=value pairs
parse_args() {
    for arg in "$@"; do
        if [[ $arg == *"="* ]]; then
            key="${arg%%=*}"
            value="${arg#*=}"
            # Export the variable so it's available to the calling script
            export "$key"="$value"
        fi
    done
}

# Check if a required environment variable is set
# Usage: check_env_var "VARIABLE_NAME" "$VARIABLE_VALUE"
check_env_var() {
    local var_name="$1"
    local var_value="$2"
    if [ -z "$var_value" ]; then
        handle_error "$var_name is not set in the environment variables"
    else
        export "$var_name"="$var_value"
        echo "Using value for $var_name: $var_value"
    fi
}

# Check if a required parameter is set (either from env or command line)
# Usage: check_param "PARAM_NAME" "$PARAM_VALUE"
check_param() {
    local param_name="$1"
    local param_value="$2"
    if [ -z "$param_value" ]; then
        handle_error "$param_name is not set (check environment variables or command line parameters)"
    else
        export "$param_name"="$param_value"
        echo "Using value for $param_name: $param_value"
    fi
}

# Handle errors with a message and exit
# Usage: handle_error "Error message"
handle_error() {
    local message="$1"
    echo "Error: $message" >&2
    exit 1
}

# Wait for Ethereum node to be ready
# Usage: wait_for_ethereum
wait_for_ethereum() {
    echo "Waiting for Ethereum node to be ready..."
    while ! curl -s -X POST -H "Content-Type: application/json" \
                 --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' \
                 "$RPC_URL" > /dev/null 2>&1
    do
        echo "Waiting for $RPC_URL"
        sleep 1
    done
    echo "Ethereum node is ready!"
}

# Set up environment based on DEPLOY_ENV
# Usage: setup_environment
setup_environment() { 
    # Set up environment based on DEPLOY_ENV
    if [ "$DEPLOY_ENV" = "LOCAL" ]; then
        check_param "RPC_URL" "${RPC_URL:-http://localhost:8545}"
    else
        check_param "RPC_URL" "${RPC_URL:-}"
    fi
    echo "Using RPC URL: $RPC_URL"

    # Wait for Ethereum node to be ready
    wait_for_ethereum
}

# Ensure an account has sufficient balance
# Usage: ensure_balance "0x..." [rpc_url]
ensure_balance() {
    local address="$1"
    local rpc_url="${2:-$RPC_URL}"
    local balance
    balance=$(cast balance "$address" --rpc-url "$rpc_url")

    while [ "$balance" = "0" ]; do
        if [ "${DEPLOY_ENV:-}" = "LOCAL" ]; then
            cast rpc anvil_setBalance "$address" 0x10000000000000000000000 -r "$rpc_url" > /dev/null 2>&1 || \
                handle_error "Failed to set balance for $address"
        else
            echo "Waiting for $address to have a balance. Current: $balance..."
            sleep 5
        fi
        balance=$(cast balance "$address" --rpc-url "$rpc_url")
    done

    echo "Account $address has balance: $balance"
}

# Get chain ID from RPC endpoint
# Usage: get_chain_id [rpc_url]
# If rpc_url is not provided, uses RPC_URL
get_chain_id() {
    local rpc_url="${1:-$RPC_URL}"
    cast chain-id --rpc-url "$rpc_url"
}

# Create directory if it doesn't exist
# Usage: ensure_dir "/path/to/directory"
ensure_dir() {
    local dir="$1"
    mkdir -p "$dir"
}

# Save deployment data to a file
# Usage: save_deployment_data "filename" "data"
save_deployment_data() {
    local filename="$1"
    local data="$2"
    ensure_dir "$(dirname "$filename")"
    echo "$data" > "$filename"
}

# Load deployment data from a file
# Usage: load_deployment_data "filename"
load_deployment_data() {
    local filename="$1"
    local fail_on_missing="${2:-false}"
    if [ -f "$filename" ]; then
        cat "$filename"
    else
        if [ "$fail_on_missing" = "true" ]; then
            handle_error "Deployment file $filename not found"
        else
            echo ""
        fi
    fi
}

transfer_ecdsa_ownership() {
    # Arguments (all optional, will fallback to env/params if not provided)
    # $1 - WAVS_SERVICE_MANAGER_ADDRESS
    # $2 - PROXY_OWNER
    # $3 - AVS_OWNER
    # $4 - FUNDED_KEY

    local wsm_address="${1}"
    local proxy_owner="${2}"
    local avs_owner="${3}"
    local funded_key="${4}"
    local mode="${5}"

    local avs_registrar_address
    if [ "$mode" == "eigen" ]; then
        # Get the AllocationManager address from the WAVS Service Manager
        local allocation_manager_address
        allocation_manager_address=$(cast call "$wsm_address" "getAllocationManager()(address)" --rpc-url "$RPC_URL")
        echo "Allocation manager address: $allocation_manager_address"
        # Get the AVS Registrar address from the AllocationManager for the WAVS Service Manager
        avs_registrar_address=$(cast call "$allocation_manager_address" "getAVSRegistrar(address)(address)" "$wsm_address" --rpc-url "$RPC_URL")
        echo "AVS registrar address: $avs_registrar_address"
    fi
    # Get the StakeRegistry address from the WAVS Service Manager
    local stake_registry_address
    stake_registry_address=$(cast call "$wsm_address" "getStakeRegistry()(address)" --rpc-url "$RPC_URL")
    echo "Stake registry address: $stake_registry_address"

    # Get the ProxyAdmin of the WAVS Service Manager
    local proxy_admin_address
    proxy_admin_address=$(cast storage "$wsm_address" "0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103" --rpc-url "$RPC_URL" | tail -n1 | sed 's/^0x000000000000000000000000//')
    proxy_admin_address="0x$proxy_admin_address"
    echo "Proxy admin address: $proxy_admin_address"

    echo "Transferring proxy ownership to $proxy_owner"
    cast send "$proxy_admin_address" "transferOwnership(address)" "$proxy_owner" --private-key "$funded_key" --rpc-url "$RPC_URL"

    if [ "$mode" == "eigen" ]; then
        echo "Transferring avs registrar ownership to $avs_owner"
        cast send "$avs_registrar_address" "transferOwnership(address)" "$avs_owner" --private-key "$funded_key" --rpc-url "$RPC_URL"
    fi

    echo "Transferring stake registry ownership to $avs_owner"
    cast send "$stake_registry_address" "transferOwnership(address)" "$avs_owner" --private-key "$funded_key" --rpc-url "$RPC_URL"

    echo "Transferring allocation manager ownership to $avs_owner"
    cast send "$wsm_address" "transferOwnership(address)" "$avs_owner" --private-key "$funded_key" --rpc-url "$RPC_URL"

    echo "Ownership transferred successfully"
}
