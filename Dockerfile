FROM envoyproxy/envoy:v1.15-latest

USER root

RUN apt-get update && apt-get install gettext-base -y

USER envoy

ENV ENVOY_HOME=/home/envoy

RUN mkdir -p $ENVOY_HOME

COPY ./envoy.tmpl $ENVOY_HOME/
COPY ./run.sh /

ENV ENVOY_TEMPLATE=$ENVOY_HOME/envoy.tmpl \
    ENVOY_CONFIG=$ENVOY_HOME/envoy.yaml \
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
    CERT_FILE=$ENVOY_HOME/server.crt \
    KEY_FILE=$ENVOY_HOME/server.key

ENTRYPOINT ["/bin/bash", "/run.sh"]
CMD [""]
