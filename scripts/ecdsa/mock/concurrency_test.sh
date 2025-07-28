#!/usr/bin/env bash
set -euo pipefail

# This script runs N mock deploy commands concurrently or serially in a single persistent container.
# Make sure you have anvil running in the background and that the variables
# below are set correctly before running the script.
######### CONFIGURATION #########
N=50 # Change this to how many wallets you want
CONCURRENT=true
MIDDLEWARE_IMAGE="ghcr.io/lay3rlabs/wavs-middleware:0.5.0-beta.8"
ANVIL_RPC_URL="http://localhost:8545"
ANVIL_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 # default anvil key
################################

WALLETS=()
ADDRESSES=()
FINISHED_COUNT=0
CONTAINER_ID=""
TEMP_DIR=$(mktemp -d -t container-base-XXXXXXXX)

kill_docker() {
  if [ -n "$CONTAINER_ID" ]; then
    echo "Killing container $CONTAINER_ID..."
    docker kill "$CONTAINER_ID" &>/dev/null || true
    docker rm -f "$CONTAINER_ID" &>/dev/null || true
  fi
}

exit_error() {
  kill_docker
  exit 1
}

check_prerequisites() {
  # 1. Exit early with an error message if anvil is not running
  # We check it by a simple cast command to get gas price 
  if ! cast gas-price --rpc-url "$ANVIL_RPC_URL" &>/dev/null; then
    echo "Anvil is not running on $ANVIL_RPC_URL. Please start it first."
    exit_error
  fi
}


generate_and_fund_wallets() {
  echo "Generating $N random wallets..."
  for i in $(seq 0 $((N - 1))); do
    WALLET=$(cast wallet new --json)
    ADDRESS=$(echo "$WALLET" | jq -r '.[0].address')
    PRIVATE_KEY=$(echo "$WALLET" | jq -r '.[0].private_key')

    # Check for duplicate private keys
    if [ $i -ne 0 ] && [[ " ${WALLETS[@]} " =~ " $PRIVATE_KEY " ]]; then
      echo "ERROR: Duplicate private key found: $PRIVATE_KEY"
      exit_error
    fi

    echo "[$i] Wallet: $ADDRESS"
    echo "Funding..."

    # Fund wallet
    cast send --rpc-url "$ANVIL_RPC_URL" --private-key "$ANVIL_PRIVATE_KEY" "$ADDRESS" --value 1ether
    WALLETS+=("$PRIVATE_KEY")
  done
}

start_container() {
  # Starts container with no entrypoint and launches it in the background so we can execute more commands against it
  echo "Starting container..."
  CONTAINER_ID=$(docker run -d --network host --entrypoint "" -v "$TEMP_DIR:/root/.nodes" $MIDDLEWARE_IMAGE tail -f /dev/null)
  echo "Container started with ID: $CONTAINER_ID"
}

mine_a_block() {
  CURRENT_BLOCK=$(cast block --rpc-url "$ANVIL_RPC_URL" --format-json | jq -r '.number')
  while true; do
    cast rpc evm_mine --rpc-url $ANVIL_RPC_URL &>/dev/null || true
    NEW_BLOCK=$(cast block --rpc-url "$ANVIL_RPC_URL" --format-json | jq -r '.number')
    if [ "$NEW_BLOCK" != "$CURRENT_BLOCK" ]; then
      break
    fi
  done
}

check_deployment() {
  DEPLOYMENT_NUMBER=$1
  if [ "${FINISHED[$DEPLOYMENT_NUMBER]:-}" == true ]; then
    return
  fi

  CONFIG_FILE="$TEMP_DIR/mock-$DEPLOYMENT_NUMBER.json"

  if [ -f "$CONFIG_FILE" ]; then
    ADDRESS=$(jq -r '.addresses.WavsServiceManager' "$CONFIG_FILE")
    echo "[$i] Finished! Address: $ADDRESS (read from $CONFIG_FILE and deployed with key ${WALLETS[$i]})"
    # Check if address is empty or null
    if [ -z "$ADDRESS" ] || [ "$ADDRESS" = "null" ]; then
      echo "ERROR: [$i] Failed to extract WavsServiceManager address from $CONFIG_FILE"
      exit_error
    fi
    if [[ " ${ADDRESSES[@]:-} " =~ " $ADDRESS " ]]; then
      echo "ERROR: Duplicate address found: $ADDRESS"
      # print all the CONFIG_FILEs with that address
      for j in $(seq 0 $((N - 1))); do
        if [ -f "$TEMP_DIR/mock-$j.json" ]; then
          ADDR=$(jq -r '.addresses.WavsServiceManager' "$TEMP_DIR/mock-$j.json")
          if [ "$ADDR" = "$ADDRESS" ]; then
            echo "Found in mock-$j.json with deployer key ${WALLETS[$j]}"
          fi
        fi
      done
      exit_error
    fi
    ADDRESSES[$i]="$ADDRESS"
    FINISHED[$i]=true
    FINISHED_COUNT=$((FINISHED_COUNT + 1))
  fi
}

deploy() {
  for i in $(seq 0 $((N - 1))); do
    KEY="${WALLETS[$i]}"
    FILENAME="mock-${i}"
    echo "[$i] Starting mock deploy for $FILENAME and wallet with key ${WALLETS[$i]}"
    docker exec -d -e MOCK_DEPLOYER_KEY="$KEY" -e MOCK_RPC_URL="$ANVIL_RPC_URL" -e DEPLOY_FILE_MOCK="$FILENAME" $CONTAINER_ID /wavs/scripts/cli.sh -m mock deploy

    if [ $CONCURRENT == true ]; then
      # If concurrent, we don't wait for the deployment to finish
      echo "[$i] Deployment started for $FILENAME, continuing to next..."
    else
      # If not concurrent, we wait for the deployment to finish
      echo "[$i] Waiting for deployment of $FILENAME to finish..."
      while true; do
        check_deployment $i
        if [ "${FINISHED[$i]:-}" == true ]; then
          break
        fi
        echo "[$i] Deployment of $FILENAME is still in progress..."
        sleep 1s
        # mine_a_block
      done
    fi
  done
}

wait_all_deployments() {
  # Wait for all processes concurrently and collect addresses
  while true; do
    if [ $FINISHED_COUNT -eq $N ]; then
      break
    fi
    for i in $(seq 0 $((N - 1))); do
      check_deployment $i
    done
    sleep 1s
  done
}

# MAIN
check_prerequisites
start_container
generate_and_fund_wallets
deploy
wait_all_deployments



if [ $FINISHED_COUNT -eq $N ]; then
  echo "All deployments finished successfully!"
else
  echo "Some deployments failed."
fi

echo "Collected addresses:"
for i in $(seq 0 $((N - 1))); do
  if [ -z "${ADDRESSES[$i]:-}" ]; then
    echo "[$i] No address collected for wallet with key ${WALLETS[$i]:-}"
    continue
  else
    echo "[$i] ${ADDRESSES[$i]} (deployed with key ${WALLETS[$i]})"
  fi
done

kill_docker