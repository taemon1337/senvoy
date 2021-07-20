# Simple Envoy TLS Sidecar

A simple wrapper container around Envoy that eases configuration and delegates to Envoy for a simple TLS sidecar proxy.

## Rationale

The Envoy Proxy is a very robust, well-proven piece of proxy technology and it supports all major protocols, features, bells, whistles, etc.  This is also an issue when being deployed in a simple configuration (such as a TLS sidecar) where you just want a robust and simple proxy up and running fast without the config headache hassel.

This project gives you the best of both worlds, up and running fast with hardened, production ready proxy.

## Usage

```bash
  docker pull taemon1337/senvoy:latest
  docker run --rm -it -p 8443:8443 taemon1337/senvoy:latest
```

The following will set the listener port via environment variable and cli arg
```bash
  docker run --rm -it -p 8443:8443 -e LISTEN_PORT=8443 taemon1337/senvoy:latest
  docker run --rm -it -p 8443:8443 taemon1337/senvoy:latest --listen-port 8443
```

A more live/production usage may look something like this:
```
  export CERT_DIR=/etc/tls/certs
  export KEY_DIR=/etc/tls/private
  export PROD_CERT=prod.crt
  export PROD_KEY=prod.key
  docker run --rm -it -p 8443:8443 \
    -v ${CERT_DIR}:${CERT_DIR}:ro \
    -v ${KEY_DIR}:${KEY_DIR}:ro \
    taemon1337/senvoy:latest \
    --cert-file ${CERT_DIR}/${PROD_CERT} \
    --key-file ${KEY_DIR}${PROD_KEY} \
    --listen-port 8443 \
    --upstream-port 80
```

The following environment variables with their defaults which can be overridden are shown below:

|Environment Variable| Command Line option|Default Value|
|--------------------|--------------------|-------------|
|ENVOY_HOME||/var/run/envoy|Location of envoy generated/copied files|
|ENVOY_TEMPLATE|--envoy-template|/usr/local/src/envoy.tmpl|Location of envoy template file|
|ENVOY_CONFIG|--envoy-config|/var/run/envoy/envoy.yaml|Location to store envoy config file|
|ENVOY_CERTS|--envoy-certs|/var/run/envoy/certs|Location to store envoy generated/copied certs|
|LISTEN_ADDRESS|--listen-addr|0.0.0.0|Address to list on|
|LISTEN_PORT|--listen-port|8443|Port to listen on|
|UPSTREAM_ADDRESS|--upstream-addr|127.0.0.1|Address to proxy traffic to|
|UPSTREAM_PORT|--upstream-port|8080|Port of upstream to proxy traffic to|
|PATH_PREFIX|--path-prefix|/|The incoming request path to match prefix on|
|PATH_REWRITE|--path-rewrite|/|The upstream request path to rewrite the prefix to|
|METRICS_ADDRESS|--metrics-addr|0.0.0.0|Address to host admin metrics on|
|METRICS_PORT|--metrics-port|8082|Port of metrics admin|
|CONNECT_TIMEOUT|--connect-timeout|0.25s|Length of time to wait for upstream|
|HOSTNAME|--hostname|localhost|The hostname to put in generated tls cert|
|CERT_DAYS|--cert-days|365|The number of days to make generated cert valid for|
|CERT_RSABITS|--cert-rsa-bits|4096|The number of bits of generated RSA key in TLS cert|
|CERT_FILE|--cert-file|/home/envoy/server.crt|Location of tls cert file|
|KEY_FILE|--key-file|/home/envoy/server.key|Location of tls key file|
|REQUIRE_CLIENT_CERT|--require-client-cert|false|If true, require client tls cert (mutual auth)|
|ALLOW_SAN|--allow-san|""|If set, only allow matching SANs|
|ALLOW_SAN_MATCHER|--allow-san-matcher|exact|The envoy string matcher to use, can be exact, contains, prefix, suffix|

## Docker entrypoint wrapper

The `run.sh` script performs the following steps:

1. Generates self-signed TLS certificates (if the CERT_FILE|--cert-file does not exist)
2. Generates an Envoy static config and writes it to disk
3. Calls the original Envoy docker-entrypoint.sh with the `--config-path <generated-envoy-config>` and any additional options you pass through

