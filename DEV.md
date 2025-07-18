# Development Setup

## Prerequisites

- Foundry

## Check Solidity

The following will build all solidity files, if you want to check them (but designed to run inside docker, see [README.md](./README.md):

```bash
forge build --root ./contracts
```

- Docker

build:

```bash
docker build -t wavs-middleware .
```

start holesky fork:

```bash docci-background docci-delay-after=2
RPC_URL=https://ethereum-holesky-rpc.publicnode.com
anvil --fork-url $RPC_URL --host 0.0.0.0 --port 8545
```

deploy:

```bash
cd docker/
FUNDED_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
METADATA_URI=https://wavs.xyz/metadata.json
LST_STRATEGY_ADDRESS=0x7D704507b76571a51d9caE8AdDAbBFd0ba0e63d3
docker run --rm --network host -v ./.nodes:/root/.nodes \
  -e FUNDED_KEY=${FUNDED_KEY} \
  -e METADATA_URI=${METADATA_URI} \
  -e LST_STRATEGY_ADDRESS=${LST_STRATEGY_ADDRESS} \
  wavs-middleware deploy
```

set service uri:

```bash
docker run --rm --network host -v ./.nodes:/root/.nodes \
  wavs-middleware set_service_uri SERVICE_URI="https://ipfs.url/for-custom-service.json"
```

register as operator:

```bash
LST_CONTRACT_ADDRESS=0x3F1c547b21f65e10480dE3ad8E19fAAC46C95034
WAVS_DELEGATE_AMOUNT=1000000000000000

OPERATOR_KEY=$(cast wallet new --json | jq -r '.[0].private_key')
OPERATOR_ADDRESS=$(cast wallet addr --private-key "$OPERATOR_KEY")
echo "Operator address: $OPERATOR_ADDRESS"

AVS_KEY=$(cast wallet new --json | jq -r '.[0].private_key')
AVS_SIGNING_ADDRESS=$(cast wallet addr --private-key "$AVS_KEY")
echo "AVS signing address: $AVS_SIGNING_ADDRESS"

docker run --rm --network host -v ./.nodes:/root/.nodes \
  -e LST_CONTRACT_ADDRESS=${LST_CONTRACT_ADDRESS} \
  -e LST_STRATEGY_ADDRESS=${LST_STRATEGY_ADDRESS} \
  -e OPERATOR_KEY=${OPERATOR_KEY} \
  -e WAVS_SIGNING_KEY=${AVS_SIGNING_ADDRESS} \
  -e WAVS_DELEGATE_AMOUNT=${WAVS_DELEGATE_AMOUNT} \
  wavs-middleware register
```

list operators:

```bash docci-output-contains="Operator 1:"
docker run --rm --network host -v ./.nodes:/root/.nodes \
  wavs-middleware list_operators
```

update quorum:

```bash
QUORUM_NUMERATOR=3
QUORUM_DENOMINATOR=5

docker run --rm --network host -v ./.nodes:/root/.nodes \
  -e QUORUM_NUMERATOR=${QUORUM_NUMERATOR} \
  -e QUORUM_DENOMINATOR=${QUORUM_DENOMINATOR} \
  wavs-middleware update_quorum
```

pause:

```bash
docker run --rm --network host -v ./.nodes:/root/.nodes \
  wavs-middleware pause
```

unpause

```bash
docker run --rm --network host -v ./.nodes:/root/.nodes \
  wavs-middleware unpause
```

delegate to operator

```bash
STAKER_KEY=$(cast wallet new --json | jq -r '.[0].private_key')
STAKER_ADDRESS=$(cast wallet addr --private-key "$STAKER_KEY")
echo "Staker address: $STAKER_ADDRESS"

docker run --rm --network host -v ./.nodes:/root/.nodes \
  -e LST_CONTRACT_ADDRESS=${LST_CONTRACT_ADDRESS} \
  -e LST_STRATEGY_ADDRESS=${LST_STRATEGY_ADDRESS} \
  -e STAKER_KEY=${STAKER_KEY} \
  -e OPERATOR_ADDRESS=${OPERATOR_ADDRESS} \
  -e WAVS_DELEGATE_AMOUNT=${WAVS_DELEGATE_AMOUNT} \
  wavs-middleware delegate_to_operator
```

mirror chain start

```bash docci-delay-after=2 docci-background
anvil --host 0.0.0.0 --port 8546
```

mirror deploy

```bash docci-delay-after=2
WAVS_SERVICE_MANAGER_ADDRESS=`jq -r .addresses.WavsServiceManager .nodes/avs_deploy.json`

docker run --rm --network host -v ./.nodes:/root/.nodes \
  -e FUNDED_KEY=${FUNDED_KEY} \
  -e WAVS_SERVICE_MANAGER_ADDRESS=${WAVS_SERVICE_MANAGER_ADDRESS} \
  wavs-middleware -m mirror deploy
```

mirror list operators

```bash docci-ignore docci-output-contains="Operator 1:"
SOURCE_RPC_URL=http://localhost:8545
MIRROR_RPC_URL=http://localhost:8546
WAVS_SERVICE_MANAGER_ADDRESS=`jq -r .addresses.WavsServiceManager .nodes/avs_deploy.json`
MIRROR_SERVICE_MANAGER_ADDRESS=`jq -r .addresses.WavsServiceManager .nodes/mirror.json`

docker run --rm --network host -v ./.nodes:/root/.nodes \
   -e SOURCE_SERVICE_MANAGER_ADDRESS=${WAVS_SERVICE_MANAGER_ADDRESS} \
   -e MIRROR_SERVICE_MANAGER_ADDRESS=${MIRROR_SERVICE_MANAGER_ADDRESS} \
   -e SOURCE_RPC_URL=${SOURCE_RPC_URL} \
   -e MIRROR_RPC_URL=${MIRROR_RPC_URL} \
  wavs-middleware -m mirror list_operators
```

mock deploy

```bash docci-ignore
LOCAL_CONFIG_PATH=$(pwd)/mock-config.json

MOCK_DEPLOYER_KEY=$(cast wallet new --json | jq -r '.[0].private_key')
MOCK_DEPLOYER_ADDRESS=$(cast wallet addr --private-key "$MOCK_DEPLOYER_KEY")
echo "Mock deployer address: $MOCK_DEPLOYER_ADDRESS"

docker run --rm --network host -v ./.nodes:/root/.nodes \
  -v $LOCAL_CONFIG_PATH:/wavs/contracts/deployments/wavs-mock-config.json \
  -e MOCK_DEPLOYER_KEY=${MOCK_DEPLOYER_KEY} \
  wavs-middleware -m mock deploy
```

## TODO

- Move the lib eigenlayer-middleware to contracts/eigenlayer/lib? (Only if we want to support multiple versions of the middleware at once).
