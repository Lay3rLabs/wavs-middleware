FROM ghcr.io/foundry-rs/foundry:latest

USER root
RUN apt update && apt install -yq jq curl

COPY contracts /wavs/contracts
WORKDIR /wavs/contracts
RUN forge build

COPY ./docker/start.sh /wavs/start.sh
RUN chmod +x /wavs/start.sh
WORKDIR /wavs

CMD ["/wavs/start.sh"]
