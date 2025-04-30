FROM ghcr.io/foundry-rs/foundry:latest
USER root
RUN apt update && apt install -yq jq curl

WORKDIR /wavs
COPY . /wavs/
RUN chmod +x /wavs/docker/*.sh

RUN forge build

RUN rm -rf /tmp

CMD ["/wavs/docker/deploy.sh"]
