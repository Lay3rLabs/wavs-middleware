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


```bash
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
