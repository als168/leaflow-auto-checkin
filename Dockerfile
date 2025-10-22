# Alpine Linux based Leaflow auxiliary container with TUIC + Hysteria2 support
FROM alpine:latest

ARG TUIC_VERSION=latest
ARG HY2_VERSION=latest
ARG INSTALL_AT_BUILD=true

ENV TZ=UTC \
    LANG=C.UTF-8 \
    TUIC_VERSION=${TUIC_VERSION} \
    HY2_VERSION=${HY2_VERSION} \
    TUIC_CONFIG_DIR=/etc/tuic \
    HY2_CONFIG_DIR=/etc/hysteria \
    DATA_DIR=/srv/proxy

RUN apk add --no-cache \
        bash \
        ca-certificates \
        coreutils \
        curl \
        ip6tables \
        iproute2 \
        iptables \
        iputils \
        jq \
        netcat-openbsd \
        openssl \
        socat \
        sudo \
        tar \
        tini \
        tzdata \
        unzip \
        wget

RUN addgroup -S proxy && \
    adduser -S -G proxy -h /srv/proxy -s /bin/sh proxy && \
    mkdir -p /etc/tuic /etc/hysteria /srv/proxy && \
    chown -R proxy:proxy /etc/tuic /etc/hysteria /srv/proxy

COPY docker/install-tuic-hy2.sh /usr/local/bin/install-tuic-hy2
RUN chmod +x /usr/local/bin/install-tuic-hy2

RUN if [ "$INSTALL_AT_BUILD" = "true" ]; then \
        install-tuic-hy2.sh --tuic-version "$TUIC_VERSION" --hy2-version "$HY2_VERSION"; \
    else \
        echo "Skipping TUIC/Hysteria installation during build"; \
    fi

VOLUME ["/etc/tuic", "/etc/hysteria", "/srv/proxy"]
EXPOSE 443 8443 1080

WORKDIR /srv/proxy
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/bin/sh"]
