#!/bin/bash

# -x echos all lines for debug
set -x

set -o errexit -o nounset -o pipefail
command -v shellcheck >/dev/null && shellcheck "$0"

SCRIPT_DIR="$(realpath "$(dirname "$0")")"
# shellcheck source=./helpers.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR"/helpers.sh

# source contracts/.env

# Local Deployment assumes testnet strategies, for documentation on strategies on different chains see:
# https://github.com/layr-labs/eigenlayer-contracts In the README.md
STRATEGY_ADDRESSES='[
  "0x05037a81bd7b4c9e0f7b430f1f2a22c31a2fd943",
  "0x31b6f59e1627cefc9fa174ad03859fc337666af7",
  "0x3a8fbdf9e77dfc25d09741f51d3e181b25d0c4e0",
  "0x46281e3b7fdcacdba44cadf069a94a588fd4c6ef",
  "0x70eb4d3c164a6b4a5f908d4fbb5a9caffb66bab6",
  "0x7673a47463f80c6a3553db9e54c8cdcd5313d0ac",
  "0x78dbcbef8ff94ec7f631c23d38d197744a323868",
  "0x7d704507b76571a51d9cae8addabbfd0ba0e63d3", 
  "0x80528d6e9a2babfc766965e0e26d5ab08d9cfaf9",
  "0x9281ff96637710cd9a5cacce9c6fad8c9f54631c",
  "0xaccc5a86732be85b5012e8614af237801636f8e5",
  "0xad76d205564f955a9c18103c4422d1cd94016899"
]'
# 0x7d704507b76571a51d9cae8addabbfd0ba0e63d3 is sETH on Holesky

# Check if METADATA_URI is provided
if [ -z "$METADATA_URI" ]; then
    echo "Error: METADATA_URI environment variable must be set"
    exit 1
fi

# Check if FUNDED_KEY is provided
if [ -z "$FUNDED_KEY" ]; then
    echo "Error: FUNDED_KEY environment variable must be set"
    exit 1
fi

# Build the `strategies` array as a Solidity-compatible input
# This is a workaround to get to a valid BPS value, in production strategies need to be weighed and maintained by an oracle 
declare -g combined_strategies=""
first_strategy=true

for strategy in $(echo "$STRATEGY_ADDRESSES" | jq -r '.[]'); do
    if [ "$first_strategy" = true ]; then
        combined_strategies+="(${strategy},837),"
        first_strategy=false
    else
        combined_strategies+="(${strategy},833),"
    fi
done
combined_strategies=${combined_strategies%,}

# prevents error where local run fails in rust script if you dont comment out TESTNET_RPC_URL in the env
if [ "$DEPLOY_ENV" = "LOCAL" ]; then
    unset TESTNET_RPC_URL
fi

create_operator_set() {
    local set_id="$1"
    local owner="$2"
    local WavsServiceManagerAddress="$3"

    impersonate_account "$owner"
    if [ "$DEPLOY_ENV" = "TESTNET" ]; then
        execute_transaction "created operator set $set_id with 1 strategy" \
          "cast s '$WavsServiceManagerAddress' \
             'createOperatorSets((uint32,address[])[])' \
             '[($set_id,[$LST_STRATEGY_ADDRESS])]' \
             --private-key '$FUNDED_KEY' \
             --rpc-url '$LOCAL_ETHEREUM_RPC_URL' > /dev/null 2>&1"
    else
        execute_transaction "created operator set $set_id with 1 strategy" \
          "cast s '$WavsServiceManagerAddress' \
             'createOperatorSets((uint32,address[])[])' \
             '[($set_id,[$LST_STRATEGY_ADDRESS])]' \
             --from '$owner' \
             --unlocked \
             --rpc-url '$LOCAL_ETHEREUM_RPC_URL' > /dev/null 2>&1"
    fi
    stop_impersonating "$owner"
}

update_avs_registrar() {
    local owner="$1"
    local WavsServiceManagerAddress="$2"
    local avsRegistrarAddress="$3"

    # TODO: Bug1
    impersonate_account "$owner"
    if [ "$DEPLOY_ENV" = "TESTNET" ]; then
        execute_transaction "set up the AVSRegistrar through WavsServiceManager" \
          "cast s '$WavsServiceManagerAddress' \
             'setAVSRegistrar(address)' \
             '$avsRegistrarAddress' \
             --private-key '$FUNDED_KEY' \
             --rpc-url '$LOCAL_ETHEREUM_RPC_URL' > /dev/null 2>&1"
    else
        execute_transaction "set up the AVSRegistrar through WavsServiceManager" \
          "cast s '$WavsServiceManagerAddress' \
             'setAVSRegistrar(address)' \
             '$avsRegistrarAddress' \
             --from '$owner' \
             --unlocked \
             --rpc-url '$LOCAL_ETHEREUM_RPC_URL' > /dev/null 2>&1"
    fi
    stop_impersonating "$owner"
}

update_metadata_url() {
  if [ "$DEPLOY_ENV" = "TESTNET" ]; then
    if [ ! -f "$HOME/.nodes/avs_deploy.json" ]; then
        echo "Error: $HOME/.nodes/avs_deploy.json does not exist"
        exit 1
    fi
  fi

  cat $HOME/.nodes/avs_deploy.json

  serviceManagerAddress=$(jq -r '.addresses.WavsServiceManager' "$HOME/.nodes/avs_deploy.json")
  if [ -z "$serviceManagerAddress" ] || [ "$serviceManagerAddress" = "null" ]; then
      echo "Error: Failed to read WavsServiceManager from $HOME/.nodes/avs_deploy.json"
      exit 1
  fi

  # Use METADATA_URI from environment
  if [ -z "$METADATA_URI" ]; then
      echo "Error: METADATA_URI environment variable must be set"
      exit 1
  fi
  echo "** $METADATA_URI **"

  owner=$(cast call "$serviceManagerAddress" "owner()" --rpc-url "$LOCAL_ETHEREUM_RPC_URL" | cast parse-bytes32-address)

  impersonate_account "$owner"
  if [ "$DEPLOY_ENV" = "TESTNET" ]; then
      execute_transaction "updated AVS metadata URI" \
        "cast s '$serviceManagerAddress' 'updateAVSMetadataURI(string)' \
         '$METADATA_URI' \
         --private-key '$FUNDED_KEY' \
         --rpc-url '$LOCAL_ETHEREUM_RPC_URL' > /dev/null 2>&1"
  else
      execute_transaction "updated AVS metadata URI" \
        "cast s '$serviceManagerAddress' 'updateAVSMetadataURI(string)' \
         '$METADATA_URI' \
         --from '$owner' \
         --unlocked \
         --rpc-url '$LOCAL_ETHEREUM_RPC_URL' > /dev/null 2>&1"
  fi
  stop_impersonating "$owner"

}

update_quorum_config() {
    local owner="$1"
    local stakeRegistryAddress="$2"
    impersonate_account "$owner"
    
    if [ "$DEPLOY_ENV" = "TESTNET" ]; then
        execute_transaction "update quorum config" \
          "cast s '$stakeRegistryAddress' \
             'updateQuorumConfig(((address,uint96)[]),address[])' \
             '([$combined_strategies])' \
             '[]' \
             --private-key '$FUNDED_KEY' \
             --rpc-url '$LOCAL_ETHEREUM_RPC_URL' > /dev/null 2>&1"
    else
        execute_transaction "update quorum config" \
          "cast s '$stakeRegistryAddress' \
             'updateQuorumConfig(((address,uint96)[]),address[])' \
             '([$combined_strategies])' \
             '[]' \
             --from '$owner' \
             --unlocked \
             --rpc-url '$LOCAL_ETHEREUM_RPC_URL' > /dev/null 2>&1"
    fi
    if [ $? -eq 0 ]; then
    stop_impersonating "$owner"
    else
        echo "Error: Failed to update quorum config."
        exit 1
    fi
}

update_minimum_weight() {
    local owner="$1"
    local stakeRegistryAddress="$2"
    local minimumWeight="$3"  # Very small value to ensure operators have enough stake
    
    impersonate_account "$owner"
    
    if [ "$DEPLOY_ENV" = "TESTNET" ]; then
        execute_transaction "update minimum weight" \
          "cast s '$stakeRegistryAddress' \
             'updateMinimumWeight(uint256,address[])' \
             '$minimumWeight' \
             '[]' \
             --private-key '$FUNDED_KEY' \
             --rpc-url '$LOCAL_ETHEREUM_RPC_URL' > /dev/null 2>&1"
    else
        execute_transaction "update minimum weight" \
          "cast s '$stakeRegistryAddress' \
             'updateMinimumWeight(uint256,address[])' \
             '$minimumWeight' \
             '[]' \
             --from '$owner' \
             --unlocked \
             --rpc-url '$LOCAL_ETHEREUM_RPC_URL' > /dev/null 2>&1"
    fi
    
    if [ $? -eq 0 ]; then
        stop_impersonating "$owner"
    else
        echo "Error: Failed to update minimum weight."
        exit 1
    fi
}

deploy_consumer_contract() {
    cd ../../avs-ecdsa-sol-sdk
    offchainMessageConsumerAddress=$(
        forge create --json \
          -r "$LOCAL_ETHEREUM_RPC_URL" \
          --private-key "$FUNDED_KEY" \
          --broadcast src/example-contracts/OffchainMessageConsumer.sol:OffchainMessageConsumer \
          --constructor-args "$stakeRegistryAddress" \
        | jq -r '.deployedTo'
    )
    if [ -z "$offchainMessageConsumerAddress" ] || [ "$offchainMessageConsumerAddress" = "null" ]; then
        echo "Error: Failed to read offchainMessageConsumerAddress from $HOME/.nodes/avs_deploy.json"
        exit 1
    fi

    echo "OffchainMessageConsumer for e2e testing deployed with address: $offchainMessageConsumerAddress"
    cd ../wavs-middleware
    jq --arg addr "$offchainMessageConsumerAddress" \
       '.addresses.offchainMessageConsumer = $addr' \
       contracts/deployments/wavs-middleware/$CHAIN_ID.json \
       > temp.json && mv temp.json contracts/deployments/wavs-middleware/$CHAIN_ID.json

    cp contracts/deployments/wavs-middleware/$CHAIN_ID.json ~/.nodes/avs_deploy.json
}

#############################################
###### Start of script execution ############
#############################################

mkdir -p ~/.nodes
deployer_public_key=$(cast wallet address "$FUNDED_KEY")
echo "PRIVATE_KEY=$FUNDED_KEY" >> contracts/.env
echo "$FUNDED_KEY" > ~/.nodes/deployer

if [ "$DEPLOY_ENV" = "TESTNET" ]; then
    LOCAL_ETHEREUM_RPC_URL="$TESTNET_RPC_URL"
    if [ -z "$LOCAL_ETHEREUM_RPC_URL" ]; then
        echo "Error: TESTNET_RPC_URL environment variable is not set"
        exit 1
    fi
    if [ -z "$LST_CONTRACT_ADDRESS" ]; then
        echo "Error: LST_CONTRACT_ADDRESS is not set in the environment variables."
        exit 1
    fi
    if [ -z "$LST_STRATEGY_ADDRESS" ]; then
        echo "Error: LST_STRATEGY_ADDRESS is not set in the environment variables."
        exit 1
    fi
else
    wait_for_ethereum
    cast rpc anvil_setBalance $deployer_public_key 0x10000000000000000000 -r $LOCAL_ETHEREUM_RPC_URL > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Failed to set balance for deployer"
        exit 1
    fi
    
    # This is needed for LST minting and depositing to work in local mode
    if [ -z "$LST_STRATEGY_ADDRESS" ]; then
        LST_STRATEGY_ADDRESS=$(echo "$STRATEGY_ADDRESSES" | jq -r '.[0]')
        echo "Using default LST_STRATEGY_ADDRESS for LOCAL mode: $LST_STRATEGY_ADDRESS"
        export LST_STRATEGY_ADDRESS
    fi
    
    if [ -z "$LST_CONTRACT_ADDRESS" ]; then
        # Get the LST contract address from the strategy
        LST_CONTRACT_ADDRESS=$(cast call "$LST_STRATEGY_ADDRESS" "underlyingToken()" --rpc-url "$LOCAL_ETHEREUM_RPC_URL" | cast parse-bytes32-address)
        echo "Using LST_CONTRACT_ADDRESS for LOCAL mode: $LST_CONTRACT_ADDRESS"
        export LST_CONTRACT_ADDRESS
    fi
fi

echo "Deployer address: $deployer_public_key configured for $DEPLOY_ENV environment"

cd contracts && forge script eigenlayer/script/WavsMiddlewareDeployer.s.sol --rpc-url $LOCAL_ETHEREUM_RPC_URL --private-key $FUNDED_KEY --broadcast # /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Error: Failed to run middleware deployment script"
    exit 1
fi

stakeRegistryAddress=$(cat deployments/wavs-middleware/$CHAIN_ID.json | jq -r '.addresses.stakeRegistry')
WavsServiceManagerAddress=$(cat deployments/wavs-middleware/$CHAIN_ID.json | jq -r '.addresses.WavsServiceManager')
avsRegistrarAddress=$(cat deployments/wavs-middleware/$CHAIN_ID.json | jq -r '.addresses.avsRegistrar')
[ -z "$stakeRegistryAddress" -o -z "$WavsServiceManagerAddress" -o -z "$avsRegistrarAddress" ] && { echo "Error: One or more required addresses (stakeRegistryAddress, WavsServiceManagerAddress, avsRegistrarAddress) are null or empty"; exit 1; }
echo "Middleware contracts deployed with addresses: WavsServiceManager: $WavsServiceManagerAddress, StakeRegistry: $stakeRegistryAddress, AVSRegistrar: $avsRegistrarAddress"
cp deployments/wavs-middleware/$CHAIN_ID.json ~/.nodes/avs_deploy.json

owner=$(cast call "$stakeRegistryAddress" "owner()" --rpc-url "$LOCAL_ETHEREUM_RPC_URL" | cast parse-bytes32-address)

# This function is used to deploy the consumer contract for e2e testing via signature validation
# deploy_consumer_contract

# This function is used to update the quorum config for the stake registry, defining the strategies and their BPS weights
update_quorum_config "$owner" "$stakeRegistryAddress"

# This function is used to set a very low minimum weight to ensure operators have enough stake
update_minimum_weight "$owner" "$stakeRegistryAddress" 1

# This function is used to update the AVS registrar for the stake registry, allowing injection of business logic to AVS registration
update_avs_registrar "$owner" "$WavsServiceManagerAddress" "$avsRegistrarAddress"

# This function is used to update the metadata URL for the stake registry, allowing to be indexed by the Eigenlayer frontend
# TODO: pass argument for the projects metadata url, not some weird hardcoded thing from core deploy
update_metadata_url

# This function is used to create the operator sets for the stake registry, allowing meta-avs functionality or otherwise discerneable operator sets
NUM_OPERATOR_SETS=1
for i in $(seq 1 $NUM_OPERATOR_SETS); do
    create_operator_set "$i" "$owner" "$WavsServiceManagerAddress"
done

