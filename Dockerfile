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
WORKDIR /wavs/contracts
RUN forge build

COPY ./docker/deploy.sh /wavs/deploy.sh
COPY ./docker/set_service_uri.sh /wavs/set_service_uri.sh
COPY ./docker/register.sh /wavs/register.sh
RUN chmod +x /wavs/deploy.sh /wavs/set_service_uri.sh /wavs/register.sh
WORKDIR /wavs

CMD ["/wavs/deploy.sh"]
