# Development Setup

## Prerequisites

- Foundry

## Check Solidity

The following will build the mock contracts we use for unit testing. Especially for WAVS internal, but also apps built on the wavs-foundry-template:

```bash
forge build --root ./contracts ./mocks
```

The following will build both the eigenlayer deploy scripts, if you want to check them (but designed to run inside docker, see [README.md](./README.md):

```bash
forge build --root ./contracts ./eigenlayer
```

## TODO

- Move the lib eigenlayer-middleware to contracts/eigenlayer/lib? (Only if we want to support multiple versions of the middleware at once).
