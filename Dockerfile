FROM rust AS builder

COPY operator /wavs/operator/
WORKDIR /wavs/operator
RUN cargo build --release

FROM ghcr.io/foundry-rs/foundry:latest

USER root
RUN apt update && apt install -yq jq curl

COPY --from=builder /wavs/operator/target/release/register_wavs_operator /wavs/register_wavs_operator
RUN chmod +x /wavs/register_wavs_operator

COPY contracts /wavs/contracts
WORKDIR /wavs/contracts
RUN forge build

WORKDIR /wavs
COPY ./docker/*.sh /wavs
RUN chmod +x /wavs/*.sh

CMD ["/wavs/deploy.sh"]
