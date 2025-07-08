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

```
docker build -t wavs-middleware .
```

start holesky fork:

```
RPC_URL=https://ethereum-holesky-rpc.publicnode.com
anvil --fork-url $RPC_URL --host 0.0.0.0 --port 8545
```

deploy:

```
cd docker/
FUNDED_KEY=
METADATA_URI=https://wavs.xyz/metadata.json
LST_STRATEGY_ADDRESS=0x7D704507b76571a51d9caE8AdDAbBFd0ba0e63d3
docker run --rm --network host -v ./.nodes:/root/.nodes \
  -e FUNDED_KEY=${FUNDED_KEY} \
  -e METADATA_URI=${METADATA_URI} \
  -e LST_STRATEGY_ADDRESS=${LST_STRATEGY_ADDRESS} \
  wavs-middleware deploy
```

set service uri:

```
docker run --rm --network host -v ./.nodes:/root/.nodes \
  wavs-middleware set_service_uri SERVICE_URI="https://ipfs.url/for-custom-service.json"
```

register as operator:

```
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

```
docker run --rm --network host -v ./.nodes:/root/.nodes \
  wavs-middleware list_operators
```

update quorum:

```
QUORUM_NUMERATOR=3
QUORUM_DENOMINATOR=5

docker run --rm --network host -v ./.nodes:/root/.nodes \
  -e QUORUM_NUMERATOR=${QUORUM_NUMERATOR} \
  -e QUORUM_DENOMINATOR=${QUORUM_DENOMINATOR} \
  wavs-middleware update_quorum
```

pause:

```
docker run --rm --network host -v ./.nodes:/root/.nodes \
  wavs-middleware pause
```

unpause

```
docker run --rm --network host -v ./.nodes:/root/.nodes \
  wavs-middleware unpause
```

delegate to operator

```
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

```
anvil --host 0.0.0.0 --port 8546
```

mirror deploy

```
docker run --rm --network host -v ./.nodes:/root/.nodes \
  wavs-middleware -m mirror deploy
```

mirror list operators

```
docker run --rm --network host -v ./.nodes:/root/.nodes \
  wavs-middleware -m mirror list_operators
```

mock deploy

```
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
