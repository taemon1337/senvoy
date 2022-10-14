FROM envoyproxy/envoy:v1.23-latest

USER root

COPY ./bin/* /usr/local/bin/
COPY ./templates/ /usr/local/src/

ENV ENVOY_HOME=/var/run/envoy \
    ENVOY_CERTS=/var/run/envoy/certs \
    ENVOY_CONFIG=/var/run/envoy/envoy.yaml \
    ENVOY_TEMPLATE=/usr/local/src/envoy.tmpl \
    DATA_FILE=/usr/local/src/data.yaml \
    CERT_FILE=/var/run/envoy/certs/server.crt \
    KEY_FILE=/var/run/envoy/certs/server.key \
    CA_FILE=/var/run/envoy/certs/server.crt \
    REQUIRE_CLIENT_CERT=false \
    ENTRYPOINT=docker-entrypoint.sh \
    LISTEN_ADDRESS=0.0.0.0 \
    LISTEN_PORT=8443 \
    UPSTREAM_ADDRESS=127.0.0.1 \
    UPSTREAM_PORT=8080 \
    UPSTREAM_SNI="" \
    UPSTREAM_TLS="" \
    PATH_PREFIX="/" \
    PREFIX_REWRITE="/" \
    METRICS_ADDRESS=0.0.0.0 \
    METRICS_PORT=8082 \
    CONNECT_TIMEOUT="0.25s" \
    HOSTNAME=localhost \
    CERT_DAYS=365 \
    CERT_RSABITS=4096 \
    ALLOW_SAN="" \
    ALLOW_SAN_MATCHER=exact \
    SNI=""

ENTRYPOINT ["/bin/bash", "/usr/local/bin/run.sh"]
CMD [""]
