FROM amneziawg-mikrotik-build:latest as awg

FROM alpine:3.19
RUN apk --no-cache add iproute2 bash openresolv && apk update 

COPY --from=awg /usr/bin/amneziawg-go /usr/bin/amneziawg-go
COPY --from=awg /usr/bin/awg /usr/bin/awg
COPY awg-quick /usr/bin/awg-quick

RUN  ln -s /usr/bin/awg /usr/bin/wg && \
     ln -s /usr/bin/awg-quick /usr/bin/wg-quick && \
     mkdir -p /etc/amnezia/amneziawg/

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
