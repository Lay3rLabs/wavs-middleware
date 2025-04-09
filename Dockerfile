FROM ubuntu:latest AS git-deps
RUN apt update && apt install -yq git
RUN mkdir -p /tmp/contracts/lib
COPY .gitmodules contracts/lib /tmp/
WORKDIR /tmp
# a git env required to submodule pull
RUN git init
RUN git submodule update --init --recursive

FROM rust AS builder
COPY operator /wavs/operator/
WORKDIR /wavs/operator
RUN cargo build --release

FROM ghcr.io/foundry-rs/foundry:latest

USER root
RUN apt update && apt install -yq jq curl

COPY --from=builder /wavs/operator/target/release/register_layer_operator /wavs/register_layer_operator
RUN chmod +x /wavs/register_layer_operator

COPY contracts /wavs/contracts
COPY --from=git-deps /tmp/contracts/lib /wavs/contracts/lib

WORKDIR /wavs/contracts
RUN forge build

RUN rm -rf /tmp

WORKDIR /wavs
COPY ./docker/*.sh /wavs
RUN chmod +x /wavs/*.sh

CMD ["/wavs/deploy.sh"]
