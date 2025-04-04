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

## Run

Prepare the env file:

```bash
cp docker/env.example docker/.env
# edit the RPC_URL for a paid testnet rpc endpoint
```

Start anvil in one terminal:

```bash
source docker/.env
anvil --fork-url $RPC_URL --host 0.0.0.0 --port 8545
```

Run all the following scripts in the `docker/` directory.

Deploy:

```bash
docker run --rm --network host --env-file .env  -v ./.nodes:/root/.nodes wavs-middleware
```

Set Service URI:

```bash
SERVICE_MANAGER_ADDRESS=$(jq -r '.addresses.WavsServiceManager' ./.nodes/avs_deploy.json)

docker run --rm --network host --env-file .env  -v ./.nodes:/root/.nodes   --entrypoint /wavs/set_service_uri.sh wavs-middleware $SERVICE_MANAGER_ADDRESS https://ipfs.url/for-custom-service.json
```

Register: 

```bash
docker run --rm --network host --env-file .env -v ./.nodes:/root/.nodes  --entrypoint /wavs/register.sh wavs-middleware
```
