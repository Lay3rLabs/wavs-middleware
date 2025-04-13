#!/bin/bash

# -x echos all lines for debug
# set -x
deployment_path="/wavs/contracts/deployments/core/17000.json"
if [ ! -f "$deployment_path" ]; then
    echo "Error: Deployment file not found at $deployment_path"
    exit 1
fi

deployment_data=$(cat "$deployment_path")
if [ -z "$deployment_data" ]; then
    echo "Error: Failed to read deployment data from $deployment_path"
    exit 1
fi

delegation_manager_address=$(echo "$deployment_data" | jq -r '.addresses.delegation')
if [ -z "$delegation_manager_address" ] || [ "$delegation_manager_address" = "null" ]; then
    echo "Error: Failed to extract delegation manager address from deployment data"
    exit 1
fi

avs_directory_address=$(echo "$deployment_data" | jq -r '.addresses.avsDirectory')
if [ -z "$avs_directory_address" ] || [ "$avs_directory_address" = "null" ]; then
    echo "Error: Failed to extract AVS directory address from deployment data"
    exit 1
fi

echo "AVS directory address: $avs_directory_address"

# Get operator address from private key
if [ -z "$PRIVATE_KEY" ]; then
    echo "Error: PRIVATE_KEY environment variable not set"
    exit 1
fi
operator_address=$(cast wallet address "$PRIVATE_KEY")

# Check if address is registered as operator
is_registered=$(cast call "$delegation_manager_address" "isOperator(address)" "$operator_address")
if [ $? -ne 0 ]; then
    echo "Error: Failed to check if address is registered as operator"
    exit 1
fi

echo "Is registered operator: $is_registered"

# Generate random 32-byte salt
salt=$(openssl rand -hex 32)

# Get current timestamp and add 1 hour for expiry
expiry=$(($(date +%s) + 3600))

# Get AVS service manager address from deployment
wavs_service_manager_address=$(cat /root/.nodes/avs_deploy.json | jq -r '.addresses.WavsServiceManager')
if [ -z "$wavs_service_manager_address" ]; then
    echo "Error: Failed to get WavsServiceManager address"
    exit 1
fi

# Calculate registration digest hash
digest_hash=$(cast call "$avs_directory_address" \
    "calculateOperatorAVSRegistrationDigestHash(address,address,bytes32,uint256)" \
    "$operator_address" \
    "$wavs_service_manager_address" \
    "0x$salt" \
    "$expiry")

if [ $? -ne 0 ]; then
    echo "Error: Failed to calculate operator AVS registration digest hash"
    exit 1
fi

# Sign the digest hash with private key
signature=$(cast wallet sign --private-key "$PRIVATE_KEY" "$digest_hash")
if [ $? -ne 0 ]; then
    echo "Error: Failed to sign digest hash"
    exit 1
fi

# Create operator signature tuple string
operator_signature="($signature,0x$salt,$expiry)"

echo "Registration digest hash: $digest_hash"

# Get stake registry address from deployment
stake_registry_address=$(cat /root/.nodes/avs_deploy.json | jq -r '.addresses.stakeRegistry')
if [ -z "$stake_registry_address" ] || [ "$stake_registry_address" = "null" ]; then
    echo "Error: Failed to get StakeRegistry address"
    exit 1
fi

# Register operator with signature
register_tx=$(cast send --private-key "$PRIVATE_KEY" \
    "$stake_registry_address" \
    "registerOperatorWithSignature((bytes,bytes32,uint256),address)" \
    "$operator_signature" \
    "$operator_address")

if [ $? -ne 0 ]; then
    echo "Error: Failed to register operator"
    exit 1
fi

register_tx_hash=$(echo "$register_tx" | jq -r '.transactionHash')

echo "Tx hash: $register_tx_hash"
