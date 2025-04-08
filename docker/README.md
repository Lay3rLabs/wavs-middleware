# Docker

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
# edit the RPC_URL for a paid testnet rpc endpoint
```

## Testnet Fork

Start anvil in one terminal:

```bash
source docker/.env
anvil --fork-url $RPC_URL --host 0.0.0.0 --port 8545
```

## Deploy

Run all the following scripts in the `docker/` directory.

Deploy:

```bash
docker run --rm --network host --env-file .env  -v ./.nodes:/root/.nodes wavs-middleware
```

Set Service URI:

```bash
docker run --rm --network host --env-file .env  -v ./.nodes:/root/.nodes   --entrypoint /wavs/set_service_uri.sh wavs-middleware https://ipfs.url/for-custom-service.json
```

Register: 

```bash
# TODO: get the private AVS key (0x...) for this service from the WAVS node
AVS_KEY=0x974b676703542ff93841c3daeeabcbfdb6ba62101856e22d5fb6b9d2f9db42fd

docker run --rm --network host --env-file .env -v ./.nodes:/root/.nodes  --entrypoint /wavs/register.sh wavs-middleware "$AVS_KEY"
```
