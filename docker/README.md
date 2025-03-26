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

```bash
source docker/.env
docker run -it --rm --network host -e ETHERSCAN_API_KEY -e LOCAL_ETHEREUM_RPC_URL -e CHAIN_ID wavs-middleware
```
