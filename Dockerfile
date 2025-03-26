FROM ghcr.io/foundry-rs/foundry:latest

USER root
RUN apt update && apt install -yq jq curl

COPY contracts /wavs/contracts
WORKDIR /wavs/contracts
RUN forge build

COPY ./docker/deploy.sh /wavs/deploy.sh
COPY ./docker/set_service_uri.sh /wavs/set_service_uri.sh
RUN chmod +x /wavs/deploy.sh /wavs/set_service_uri.sh
WORKDIR /wavs

CMD ["/wavs/deploy.sh"]
