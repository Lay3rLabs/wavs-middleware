#!/bin/bash

# -x echos all lines for debug
# set -x

set -o errexit -o nounset -o pipefail
command -v shellcheck >/dev/null && shellcheck "$0"

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
# shellcheck source=./helpers.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR"/helpers.sh

if [ -z "$DEPLOY_ENV" ]; then
    echo "Error: DEPLOY_ENV environment variable is not set"
    exit 1
fi

if [ "$DEPLOY_ENV" = "TESTNET" ]; then
    LOCAL_ETHEREUM_RPC_URL="$TESTNET_RPC_URL"
else
    LOCAL_ETHEREUM_RPC_URL=${LOCAL_ETHEREUM_RPC_URL:-http://localhost:8545}
fi

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
