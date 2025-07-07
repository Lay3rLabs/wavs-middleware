#!/bin/bash

# -x echos all lines for debug
# set -x

set -o errexit -o nounset -o pipefail
command -v shellcheck >/dev/null && shellcheck "$0"

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
# shellcheck source=../../helper.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../helper.sh"

# Parse command line arguments in key=value format
parse_args "$@"

# Check required parameters with defaults
check_param "DEPLOY_ENV" "${DEPLOY_ENV:-LOCAL}"
check_param "SERVICE_URI" "${SERVICE_URI:-}"
DEFAULT_SERVICE_MANAGER=$(jq -r '.addresses.WavsServiceManager' "$HOME/.nodes/avs_deploy.json" || true)
check_param "WAVS_SERVICE_MANAGER_ADDRESS" "${WAVS_SERVICE_MANAGER_ADDRESS:-$DEFAULT_SERVICE_MANAGER}"

# Set up environment based on DEPLOY_ENV
setup_environment

# Read the deployer private key from file
deployer_private_key=$(load_deployment_data "$HOME/.nodes/deployer")
deployer_address=$(cast wallet address "$deployer_private_key")
echo "Deployer address: $deployer_address"

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

set_service_uri "$WAVS_SERVICE_MANAGER_ADDRESS" "$SERVICE_URI"
