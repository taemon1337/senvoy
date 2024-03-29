FROM envoyproxy/envoy:v1.24-latest

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
    LISTEN_HTTP_ADDRESS="" \
    LISTEN_HTTP_PORT=8080 \
    HTTP_FORWARD_PROXY="" \
    SNI_FORWARD_PROXY="" \
    SNI_FORWARD_PROXY_PORT=443 \
    PATH_PREFIX="/" \
    PREFIX_REWRITE="/" \
    METRICS_ADDRESS=0.0.0.0 \
    METRICS_PORT=8082 \
    CONNECT_TIMEOUT="0.25s" \
    HOSTNAME=localhost \
    CERT_DAYS=365 \
    CERT_RSABITS=4096 \
    ALLOW_SAN="" \
    ALLOW_SAN_MATCHER=exact

ENTRYPOINT ["/bin/bash", "/usr/local/bin/run.sh"]
CMD [""]
