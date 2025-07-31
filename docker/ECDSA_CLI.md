# TODO: .

## Setup

```bash
docker build -t wavs-middleware .
```

```bash docci-if-not-exists="docker/.env"
CHAIN=holesky
cp docker/env.example.$CHAIN docker/.env
```

## Test

Terminal 1

```bash docci-background
source docker/.env
anvil --fork-url $FORK_RPC_URL --host 0.0.0.0 --port 8545
```

Terminal 2

```bash docci-background
anvil --host 0.0.0.0 --port 8546
```

Terminal 3

<!-- Ensures that the last command outputs operator 1 (i.e. they were registered) -->

```bash docci-delay-before="3" docci-delay-per-cmd=0.1 docci-output-contains="Operator 1:"
cd docker/

docker run --rm --network host -v ./.nodes:/root/.nodes \
   --env-file .env \
   wavs-middleware deploy

docker run --rm --network host -v ./.nodes:/root/.nodes \
   --env-file .env \
   wavs-middleware set_service_uri SERVICE_URI="https://ipfs.url/for-custom-service.json"

OPERATOR_KEY=$(cast wallet new --json | jq -r '.[0].private_key')
OPERATOR_ADDRESS=$(cast wallet addr --private-key "$OPERATOR_KEY")
echo "Operator address: $OPERATOR_ADDRESS"
AVS_KEY=$(cast wallet new --json | jq -r '.[0].private_key')
AVS_SIGNING_ADDRESS=$(cast wallet addr --private-key "$AVS_KEY")
echo "AVS signing address: $AVS_SIGNING_ADDRESS"
docker run --rm --network host -v ./.nodes:/root/.nodes \
   --env-file .env \
   -e OPERATOR_KEY=${OPERATOR_KEY} \
   -e WAVS_SIGNING_KEY=${AVS_SIGNING_ADDRESS} \
   wavs-middleware register WAVS_DELEGATE_AMOUNT=1000000000000000

docker run --rm --network host -v ./.nodes:/root/.nodes \
   --env-file .env \
   wavs-middleware update_quorum QUORUM_NUMERATOR=3 QUORUM_DENOMINATOR=5

STAKER_KEY=$(cast wallet new --json | jq -r '.[0].private_key')
STAKER_ADDRESS=$(cast wallet addr --private-key "$STAKER_KEY")
echo "Staker address: $STAKER_ADDRESS"
docker run --rm --network host -v ./.nodes:/root/.nodes \
   --env-file .env \
   -e STAKER_KEY=${STAKER_KEY} \
   -e OPERATOR_ADDRESS=${OPERATOR_ADDRESS} \
   wavs-middleware delegate_to_operator WAVS_DELEGATE_AMOUNT=1000000000000000

docker run --rm --network host -v ./.nodes:/root/.nodes \
   --env-file .env \
   wavs-middleware list_operators
```

<!-- Ensures the list_operators 3/5 quorum persisted from the mirror deploy -->

```bash docci-output-contains="Quorum: 3/5"
docker run --rm --network host -v ./.nodes:/root/.nodes \
   wavs-middleware -m mirror deploy

docker run --rm --network host -v ./.nodes:/root/.nodes \
   wavs-middleware -m mirror list_operators
```

<!-- assets the operators on the mirror is now empty -->

```bash docci-output-contains='"operators": []'
docker run --rm --network host -v ./.nodes:/root/.nodes \
   --env-file .env \
   -e OPERATOR_KEY=${OPERATOR_KEY} \
   wavs-middleware deregister

sleep 1

docker run --rm --network host -v ./.nodes:/root/.nodes \
   wavs-middleware -m mirror list_operators
```

<!-- When paused a new operator can not be registered -->

```bash docci-assert-failure
docker run --rm --network host -v ./.nodes:/root/.nodes \
   --env-file .env \
   wavs-middleware pause

OPERATOR_KEY=$(cast wallet new --json | jq -r '.[0].private_key')
OPERATOR_ADDRESS=$(cast wallet addr --private-key "$OPERATOR_KEY")
AVS_KEY=$(cast wallet new --json | jq -r '.[0].private_key')
AVS_SIGNING_ADDRESS=$(cast wallet addr --private-key "$AVS_KEY")

# this command will fail for the paused state
docker run --rm --network host -v ./.nodes:/root/.nodes \
   --env-file .env \
   -e OPERATOR_KEY=${OPERATOR_KEY} \
   -e WAVS_SIGNING_KEY=${AVS_SIGNING_ADDRESS} \
   wavs-middleware register WAVS_DELEGATE_AMOUNT=1000000000000000
```

<!-- unpaused last state from previous codeblock -->

```bash
docker run --rm --network host -v ./.nodes:/root/.nodes \
   --env-file .env \
   wavs-middleware unpause

PROXY_OWNER=$(cast wallet new --json | jq -r '.[0].private_key')
PROXY_OWNER_ADDRESS=$(cast wallet addr --private-key "$PROXY_OWNER")
echo "Proxy owner address: $PROXY_OWNER_ADDRESS"
AVS_OWNER=$(cast wallet new --json | jq -r '.[0].private_key')
AVS_OWNER_ADDRESS=$(cast wallet addr --private-key "$AVS_OWNER")
echo "Avs owner address: $AVS_OWNER_ADDRESS"

docker run --rm --network host -v ./.nodes:/root/.nodes \
   --env-file .env \
   wavs-middleware transfer_ownership ${PROXY_OWNER} ${AVS_OWNER}
```

```bash
MOCK_DEPLOYER_KEY=$(cast wallet new --json | jq -r '.[0].private_key')
MOCK_DEPLOYER_ADDRESS=$(cast wallet addr --private-key "$MOCK_DEPLOYER_KEY")

docker run --rm --network host -v ./.nodes:/root/.nodes \
   -e MOCK_DEPLOYER_KEY=${MOCK_DEPLOYER_KEY} \
   wavs-middleware -m mock deploy

LOCAL_CONFIG_PATH=$(pwd)/mock-config.json
docker run --rm --network host -v ./.nodes:/root/.nodes \
   -v $LOCAL_CONFIG_PATH:/wavs/contracts/deployments/wavs-mock-config.json \
   --env-file .env \
   wavs-middleware -m mock configure

PROXY_OWNER=$(cast wallet new --json | jq -r '.[0].private_key')
PROXY_OWNER_ADDRESS=$(cast wallet addr --private-key "$PROXY_OWNER")
echo "Proxy owner address: $PROXY_OWNER_ADDRESS"
AVS_OWNER=$(cast wallet new --json | jq -r '.[0].private_key')
AVS_OWNER_ADDRESS=$(cast wallet addr --private-key "$AVS_OWNER")
echo "Avs owner address: $AVS_OWNER_ADDRESS"

docker run --rm --network host -v ./.nodes:/root/.nodes \
   wavs-middleware -m mock transfer_ownership ${PROXY_OWNER} ${AVS_OWNER}
```
