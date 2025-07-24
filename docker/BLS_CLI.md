# TODO: .

## Setup

```bash
docker build -t wavs-middleware .
```

```bash docci-if-not-exists="docker/.env"
CHAIN=holesky
cp docker/env.example.$CHAIN docker/.env
```

```bash docci-background
source docker/.env
anvil --fork-url $FORK_RPC_URL --host 0.0.0.0 --port 8545
```

<!-- verifies the update_quorum was set properly in `list_operators` -->

```bash docci-output-contains="Quorum Numerator: 3"
cd docker/

docker run --rm --network host -v ./.nodes:/root/.nodes \
   --env-file .env \
   wavs-middleware -s bls deploy

docker run --rm --network host -v ./.nodes:/root/.nodes \
   --env-file .env \
   wavs-middleware -s bls set_service_uri SERVICE_URI="https://ipfs.url/for-custom-service.json"

docker run --rm --network host -v ./.nodes:/root/.nodes \
   --env-file .env \
   wavs-middleware -s bls update_quorum QUORUM_NUMERATOR=3 QUORUM_DENOMINATOR=5

OPERATOR_KEY=$(cast wallet new --json | jq -r '.[0].private_key')
OPERATOR_ADDRESS=$(cast wallet addr --private-key "$OPERATOR_KEY")
echo "Operator address: $OPERATOR_ADDRESS"

docker run --rm --network host -v ./.nodes:/root/.nodes \
   --env-file .env \
   -e OPERATOR_KEY=${OPERATOR_KEY} \
   wavs-middleware -s bls register WAVS_DELEGATE_AMOUNT=1000000000000000000

docker run --rm --network host -v ./.nodes:/root/.nodes \
   --env-file .env \
   wavs-middleware -s bls pause

docker run --rm --network host -v ./.nodes:/root/.nodes \
   --env-file .env \
   wavs-middleware -s bls unpause

docker run --rm --network host -v ./.nodes:/root/.nodes \
   --env-file .env \
   wavs-middleware -s bls list_operators
```
