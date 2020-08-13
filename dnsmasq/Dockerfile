FROM alpine:latest

RUN apk --no-cache add dnsmasq

COPY dnsmasq.conf /etc/dnsmasq.conf

EXPOSE 53/tcp
EXPOSE 53/udp

ENTRYPOINT ["dnsmasq", "--keep-in-foreground"]