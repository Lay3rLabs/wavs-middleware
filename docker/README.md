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

Start anvil in one terminal:

```bash
export RPC_URL="???"
anvil --fork-url $RPC_URL --host 0.0.0.0 --port 8545
```

```bash
export LOCAL_ETHEREUM_RPC_URL="http://localhost:8545"
export ETHERSCAN_API_KEY="foobar
docker run -it --rm --network host -e ETHERSCAN_API_KEY -e LOCAL_ETHEREUM_RPC_URL wavs-middleware
```
