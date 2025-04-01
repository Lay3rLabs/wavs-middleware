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

### Newer

Deploy:

```bash
docker run --rm --network host --env-file .env  -v ./.nodes:/root/.nodes wavs-middleware
```

Register: 


```bash
docker run --rm --network host --env-file .env -v ./.nodes/avs_deploy.json:/wavs/avs_deploy.json -v ./.nodes:/root/.nodes  --entrypoint /wavs/register.sh wavs-middleware
```

Set Service URI:

```bash
SERVICE_MANAGER_ADDRESS=$(jq -r '.addresses.WavsServiceManager' ./.nodes/avs_deploy.json)

docker run --rm --network host --env-file .env  -v ./.nodes:/root/.nodes   --entrypoint /wavs/set_service_uri.sh wavs-middleware $SERVICE_MANAGER_ADDRESS foo.bar
```

### Older

```bash
source docker/.env
docker run --rm --network host -e ETHERSCAN_API_KEY -e LOCAL_ETHEREUM_RPC_URL -e CHAIN_ID wavs-middleware
```

Set service manager:

TODO: record service manager better
TODO: get this docker run command cleaner

```bash
docker run --rm --network host -e ETHERSCAN_API_KEY -e LOCAL_ETHEREUM_RPC_URL -e CHAIN_ID --entrypoint /wavs/set_service_uri.sh wavs-middleware 0x4588f79798d3c51822b9d2f9abad5e58d44eb7c5 "https://foo.bar/baz"
```