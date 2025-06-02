#syntax=docker/dockerfile:1.7-labs

FROM ghcr.io/foundry-rs/foundry:latest AS build
USER root

COPY contracts /wavs/contracts
RUN forge build --root /wavs/contracts ./eigenlayer

# Using bookworm image saves about 100MB off using foundry directly
# bookworm-slim saves another 40MB
FROM debian:bookworm-slim

# The rm reduces size about 20MB
RUN apt update && apt install -yq jq curl && rm -rf /var/lib/apt/lists/*

# Base foundry tools (148 MB)
COPY --from=build /usr/local/bin /usr/local/bin

# Our built contracts
COPY --from=build  /wavs/contracts /wavs/contracts/
# Alternate: This requires the 1.7-labs syntax and will save another 60MB
# (hopefully can remove if everything is pre-compiled)
# COPY --from=build --exclude=lib  /wavs/contracts /wavs/contracts/

WORKDIR /wavs
COPY ./scripts /wavs/scripts
RUN chmod +x /wavs/scripts/*.sh

ENTRYPOINT ["/wavs/scripts/cli.sh"]