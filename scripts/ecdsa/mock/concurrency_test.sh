#!/usr/bin/env bash
set -euo pipefail

# This script is used to test the concurrency of the WAVS middleware mock deployer.
# Make sure you have anvil running in the background and that the variables
# below are set correctly before running the script.
######### CONFIGURATION #########
N=50 # Change this to how many wallets you want
MIDDLEWARE_IMAGE="ghcr.io/lay3rlabs/wavs-middleware:0.5.0-beta.7"
ANVIL_RPC_URL="http://localhost:8545"
ANVIL_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 # default anvil key
################################

WALLETS=()
TEMP_DIRS=()

# 1. Exit early with an error message if anvil is not running
# We check it by a simple cast command to get gas price 
if ! cast gas-price --rpc-url "$ANVIL_RPC_URL" &>/dev/null; then
  echo "Anvil is not running on $ANVIL_RPC_URL. Please start it first."
  exit 1
fi

# 1. Generate wallets
echo "Generating $N random wallets..."
for i in $(seq 1 $N); do
  WALLET=$(cast wallet new --json)
  ADDRESS=$(echo "$WALLET" | jq -r '.[0].address')
  PRIVATE_KEY=$(echo "$WALLET" | jq -r '.[0].private_key')

  WALLETS+=("$PRIVATE_KEY")

  echo "[$i] Wallet: $ADDRESS"
  echo "Funding..."

  # 2. Fund wallet (serially)
  cast send --rpc-url "$ANVIL_RPC_URL" --private-key "$ANVIL_PRIVATE_KEY" "$ADDRESS" --value 1ether
done

# 2. Create temp dirs
for i in $(seq 1 $N); do
  TMP_DIR=$(mktemp -d -t nodes-$i-XXXXXXXX)
  TEMP_DIRS+=("$TMP_DIR")
done

# 3. Run containers in parallel
echo "Launching $N containers..."

PIDS=()
for i in $(seq 0 $((N - 1))); do
  KEY="${WALLETS[$i]}"
  DIR="${TEMP_DIRS[$i]}"

  echo "[$((i + 1))] Starting container"

  docker run --rm --network host \
    -v "$DIR:/root/.nodes" \
    -e MOCK_DEPLOYER_KEY="$KEY" \
    -e MOCK_RPC_URL="$ANVIL_RPC_URL" \
    $MIDDLEWARE_IMAGE -m mock deploy &
  
  PIDS+=($!)
done

# Wait for all processes concurrently
echo "Waiting for all containers to finish..."
FAILED_CONTAINERS=()
PROCESSED_PIDS=()

# Monitor all processes concurrently
FINISHED_COUNT=0

while [ $FINISHED_COUNT -lt ${#PIDS[@]} ]; do
  # Check each process
  for i in "${!PIDS[@]}"; do
    PID=${PIDS[$i]}
    
    # Skip if we already processed this PID
    if [[ " ${PROCESSED_PIDS[@]:-} " =~ " $PID " ]]; then
      continue
    fi
    
    # Check if process is still running
    # `kill -0` checks if the process exists without actually sending the kill signal
    if ! kill -0 $PID 2>/dev/null; then
      echo "Container $((i+1)) (PID: $PID) is not running, checking exit status..."
      # Process finished, use non-blocking wait to get exit code
      if wait $PID 2>/dev/null || true; then
        # Check the actual exit status from the wait command
        EXIT_CODE=$?
        if [ $EXIT_CODE -eq 0 ]; then
          echo "Container $((i+1)) finished successfully"
        else
          echo "Container $((i+1)) failed with exit code $EXIT_CODE"
          FAILED_CONTAINERS+=($((i+1)))
        fi
      else
        echo "Container $((i+1)) finished successfully"
      fi
      
      PROCESSED_PIDS+=($PID)
      FINISHED_COUNT=$((FINISHED_COUNT + 1))
    else 
        echo "Container $((i+1)) (PID: $PID) is still running..."
    fi
  done
  
  # Small sleep to avoid busy waiting
  sleep 1
done

# Report results
if [ ${#FAILED_CONTAINERS[@]} -eq 0 ]; then
  echo "All containers finished successfully."
else
  echo "Failed containers: ${FAILED_CONTAINERS[*]}"
  exit 1
fi
