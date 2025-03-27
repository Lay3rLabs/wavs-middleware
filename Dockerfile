FROM rust
RUN curl -L https://foundry.paradigm.xyz | bash
RUN ~/.foundry/bin/foundryup 
ENV PATH="/root/.foundry/bin:${PATH}"

USER root
RUN apt update && apt install -yq jq curl
COPY operator /wavs/operator/
WORKDIR /wavs/operator
RUN cargo build 

COPY contracts /wavs/contracts
WORKDIR /wavs/contracts
RUN forge build

COPY ./docker/deploy.sh /wavs/deploy.sh
COPY ./docker/set_service_uri.sh /wavs/set_service_uri.sh
COPY ./docker/register.sh /wavs/register.sh
RUN chmod +x /wavs/deploy.sh /wavs/set_service_uri.sh /wavs/register.sh
WORKDIR /wavs

CMD ["/wavs/deploy.sh"]
