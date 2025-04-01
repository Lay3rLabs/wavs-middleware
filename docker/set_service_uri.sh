#!/bin/bash

set -e
# set -xe

export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

if [ -z "$DEPLOY_ENV" ]; then
    echo "Error: DEPLOY_ENV environment variable is not set"
    exit 1
fi

if [ "$DEPLOY_ENV" = "TESTNET" ]; then
    LOCAL_ETHEREUM_RPC_URL="$TESTNET_RPC_URL"
else
    LOCAL_ETHEREUM_RPC_URL=${LOCAL_ETHEREUM_RPC_URL:-http://localhost:8545}
fi

impersonate_account() {
    local account="$1"
    if [ "$DEPLOY_ENV" = "TESTNET" ]; then
        return 0
    fi
    cast rpc anvil_impersonateAccount $account -r $LOCAL_ETHEREUM_RPC_URL > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        handle_error "Failed to impersonate account $account"
    fi
    cast rpc anvil_setBalance $account 0x10000000000000000000 -r $LOCAL_ETHEREUM_RPC_URL > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        handle_error "Failed to set balance for account $account"
    fi
}

handle_error() {
    local message="$1"
    echo "Error: $message"
    exit 1
}

check_env_var() {
    local var_name="$1"
    local var_value="$2"
    if [ -z "$var_value" ]; then
        handle_error "$var_name is not set in the environment variables"
    fi
}

execute_transaction() {
    local description="$1"
    local command="$2"

    eval "$command"

    if [ $? -eq 0 ]; then
        echo "Successfully $description"
    else
        handle_error "Failed to $description"
    fi
}

stop_impersonating() {
    local account="$1"
    if [ "$DEPLOY_ENV" = "TESTNET" ]; then
        return 0
    fi
    cast rpc anvil_stopImpersonatingAccount "$account" -r "$LOCAL_ETHEREUM_RPC_URL" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Failed to stop impersonating account $account"
        exit 1
    fi
}

set_service_uri() {
  local service_manager_address="$1"
  local service_uri="$2"

  owner=$(cast call "$service_manager_address" "owner()" --rpc-url "$LOCAL_ETHEREUM_RPC_URL" | cast parse-bytes32-address)

  impersonate_account "$owner"
  if [ "$DEPLOY_ENV" = "TESTNET" ]; then
      execute_transaction "updated AVS Service URI" \
        "cast s '$service_manager_address' 'setServiceURI(string)' \
         '$service_uri' \
         --private-key '$deployer_private_key' \
         --rpc-url '$LOCAL_ETHEREUM_RPC_URL' > /dev/null 2>&1"
  else
      execute_transaction "updated AVS Service URI" \
        "cast s '$service_manager_address' 'setServiceURI(string)' \
         '$service_uri' \
         --from '$owner' \
         --unlocked \
         --rpc-url '$LOCAL_ETHEREUM_RPC_URL' > /dev/null 2>&1"
  fi
  stop_impersonating "$owner"
}

LOCAL_ETHEREUM_RPC_URL="http://localhost:8545"
if [ -z "$1" ]; then
    echo "Error: Pass SERVICE_MANAGER_ADDRESS as first arg"
    exit 1
fi
SERVICE_MANAGER_ADDRESS="$1"
if [ -z "$2" ]; then
    echo "Error: Pass SERVICE_URI as second arg"
    exit 1
fi
SERVICE_URI="$2"

set_service_uri $SERVICE_MANAGER_ADDRESS $SERVICE_URI
