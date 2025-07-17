#syntax=docker/dockerfile:1.7-labs

FROM ghcr.io/foundry-rs/foundry:latest AS build
USER root

COPY contracts /wavs/contracts
RUN apt-get install make
RUN cd /wavs/contracts && make build

# Using bookworm image saves about 100MB off using foundry directly
# bookworm-slim saves another 40MB
FROM debian:bookworm-slim

# The rm reduces size about 20MB
RUN apt update && apt install -yq jq curl && rm -rf /var/lib/apt/lists/*

# Version 1: Base foundry tools (148 MB)
# COPY --from=build /usr/local/bin /usr/local/bin
# Version 2: Only forge and cast
RUN mkdir -p /usr/local/bin
COPY --from=build /usr/local/bin/forge /usr/local/bin/forge
COPY --from=build /usr/local/bin/cast /usr/local/bin/cast

# Version 1: Our built contracts
# COPY --from=build  /wavs/contracts /wavs/contracts/
# Version 2: Our contracts minus submodule dependencies (theoretically can remove if everything is pre-compiled, but fails now)
# This requires the 1.7-labs syntax
COPY --from=build --exclude=lib  /wavs/contracts /wavs/contracts/
# We need this to get the original solidity source from the submodules, but nothing else (15 MB vs 60 MB for all)
COPY --from=build --parents  /wavs/contracts/./lib/**/*.sol /wavs/contracts/

WORKDIR /wavs
COPY ./scripts /wavs/scripts
RUN chmod +x $(find /wavs/scripts -name '*.sh')

ENTRYPOINT ["/wavs/scripts/cli.sh"]