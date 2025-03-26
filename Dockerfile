FROM ghcr.io/foundry-rs/foundry:latest

USER root
RUN apt update && apt install -yq jq curl

COPY contracts /wavs/contracts
WORKDIR /wavs/contracts
RUN forge build

COPY ./docker/deploy.sh /wavs/deploy.sh
RUN chmod +x /wavs/deploy.sh
WORKDIR /wavs

CMD ["/wavs/deploy.sh"]
