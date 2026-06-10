FROM golang:1.24-bookworm AS builder

RUN apt-get update && apt-get install -y git

WORKDIR /outline-sdk
RUN git clone https://github.com/OutlineFoundation/outline-sdk.git .
WORKDIR /outline-sdk/x/examples/outline-cli

RUN CGO_ENABLED=1 go build -o /outline-cli -ldflags="-extldflags=-static" .

FROM lscr.io/linuxserver/wireguard:latest

COPY --from=builder /outline-cli /usr/local/bin/outline-cli
COPY root/ /

RUN chmod +x /usr/local/bin/outline-cli \
    /custom-cont-init.d/* \
    /etc/s6-overlay/s6-rc.d/svc-outline/run
