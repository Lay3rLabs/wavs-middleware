## Prerequisites

- Docker and Docker Compose
- Node.js and Yarn (will be installed in container)
- Foundry (will be installed in container)

# Docker Quick start

## Build

First, ensure you have all submodules:

```bash
git submodule update --init --recursive
```

Then, build the image:

```bash
docker build -t wavs-middleware .
```

## Setup

Prepare the env file:

```bash
cp docker/env.example docker/.env
# edit the RPC_URL for a paid testnet rpc endpoint, add funded key, and TESTNET_RPC_URL
```

## Testnet Fork

Start anvil in one terminal:

```bash
source docker/.env
anvil --fork-url $RPC_URL --host 0.0.0.0 --port 8545
```

## Deploy

**Run all the following scripts in the `docker/` directory.**

```bash
cd docker/
```

Deploy:

```bash
docker run --rm --network host --env-file .env -v ./.nodes:/root/.nodes wavs-middleware
```

Set Service URI:

```bash
SERVICE_URI="https://ipfs.url/for-custom-service.json"

docker run --rm --network host --env-file .env -v ./.nodes:/root/.nodes --entrypoint /wavs/set_service_uri.sh wavs-middleware "$SERVICE_URI"
```

Register:

```bash
# TODO: get the private AVS key (0x...) for this service from the WAVS node
# Generate a new private key for the AVS
AVS_KEY=$(cast wallet new --json | jq -r '.[0].private_key')

docker run --rm --network host --env-file .env -v ./.nodes:/root/.nodes  --entrypoint /wavs/register.sh wavs-middleware "$AVS_KEY"
```

List Operators:

```bash
# View stake registry status, including registered operators and their weights
docker run --rm --network host --env-file .env -v ./.nodes:/root/.nodes --entrypoint /wavs/list_operator.sh wavs-middleware
```
## Deploy Testnet 
Same as the local deploy, but add `TESTNET_RPC_URL` to the .env and change `DEPLOY_ENV` to `"TESTNET"`


## References

- [EigenLayer Documentation](https://docs.eigenlayer.xyz/)
- [Hello World AVS Repository](https://github.com/Layr-Labs/eigenlayer-hello-world)
