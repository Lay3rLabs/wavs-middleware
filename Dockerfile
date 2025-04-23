FROM ghcr.io/foundry-rs/foundry:latest
USER root
RUN apt update && apt install -yq jq curl

COPY contracts /wavs/contracts
RUN forge build --root /wavs/contracts

RUN rm -rf /tmp

WORKDIR /wavs
COPY ./docker/*.sh /wavs
RUN chmod +x /wavs/*.sh

CMD ["/wavs/deploy.sh"]
