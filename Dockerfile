FROM golang:1.22 AS awggo
COPY . /awg
WORKDIR /awg
RUN git clone https://github.com/amnezia-vpn/amneziawg-go.git && \
    cd amneziawg-go && \
    go mod download && \
    go mod verify && \
    go build -ldflags '-linkmode external -extldflags "-fno-PIC -static"' -v -o /usr/bin

FROM alpine:3.19 AS awgtools
ARG AWGTOOLS_RELEASE="1.0.20240213"
RUN apk --no-cache add iproute2 bash && \
    apk update && apk add git linux-headers alpine-sdk && \
    git clone https://github.com/amnezia-vpn/amneziawg-tools && \
    cd amneziawg-tools/src && \
    make all install

FROM alpine:3.19
RUN apk --no-cache add iproute2 bash openresolv && apk update 

COPY --from=awggo /usr/bin/amneziawg-go /usr/bin/amneziawg-go
COPY --from=awgtools /usr/bin/awg /usr/bin/awg
COPY awg-quick /usr/bin/awg-quick

RUN  ln -s /usr/bin/awg /usr/bin/wg && \
     ln -s /usr/bin/awg-quick /usr/bin/wg-quick && \
     mkdir -p /etc/amnezia/amneziawg/ /etc/iproute2/ && \
     echo "100 awg0" >> /etc/iproute2/rt_tables

RUN (echo "[Interface]" && \
     echo "PrivateKey = $(wg genkey)" && \
     echo "Address = 127.0.0.1/32" && \
     echo "ListenPort = 55616" \
     ) > /etc/amnezia/amneziawg/awg0.conf

CMD ["/usr/bin/awg-quick", "up", "awg0"]

# how to build 
# docker buildx build -f Dockerfile --platform linux/arm/v7 -t amneziawg-mikrotik:latest .

# how to run
# docker run --cap-add=NET_ADMIN --cap-add=NET_RAW --device /dev/net/tun -it -v $cwd/amnezia:/etc/amnezia amneziawg-mikrotik:latest bash
