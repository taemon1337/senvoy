FROM envoyproxy/envoy:v1.18-latest

USER root

RUN apt-get update && apt-get install gettext-base -y

COPY ./envoy.tmpl /tmp/
COPY ./run.sh /

ENV ENVOY_HOME=/var/run/envoy \
    ENVOY_CERTS=/var/run/envoy/certs \
    ENVOY_CONFIG=/var/run/envoy/envoy.yaml \
    ENVOY_TEMPLATE=/tmp/envoy.tmpl \
    CERT_FILE=/var/run/envoy/certs/server.crt \
    KEY_FILE=/var/run/envoy/certs/server.key \
    CA_FILE=/var/run/envoy/certs/server.crt \
    REQUIRE_CLIENT_CERT=false \
    ENTRYPOINT=docker-entrypoint.sh \
    LISTEN_ADDRESS=0.0.0.0 \
    LISTEN_PORT=8443 \
    UPSTREAM_ADDRESS=127.0.0.1 \
    UPSTREAM_PORT=8080 \
    METRICS_ADDRESS=0.0.0.0 \
    METRICS_PORT=8082 \
    CONNECT_TIMEOUT="0.25s" \
    HOSTNAME=localhost \
    CERT_DAYS=365 \
    CERT_RSABITS=4096 \
    ALLOW_SAN=localhost

ENTRYPOINT ["/bin/bash", "/run.sh"]
CMD [""]
