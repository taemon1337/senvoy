# Simple Envoy TLS Sidecar

A simple wrapper container around Envoy that eases configuration and delegates to Envoy for a simple TLS sidecar proxy.

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

The following environment variables with their defaults which can be overridden are shown below:

|Environment Variable| Command Line option|Default Value|
|--------------------|--------------------|-------------|
|ENVOY_HOME||/home/envoy|
|ENVOY_TEMPLATE|--envoy-template|/home/envoy/envoy.tmpl|
|ENVOY_CONFIG|--envoy-config|/home/envoy/envoy.yaml|
|LISTEN_ADDRESS|--listen-addr|0.0.0.0|
|LISTEN_PORT|--listen-port|8443|
|UPSTREAM_ADDRESS|--upstream-addr|127.0.0.1|
|UPSTREAM_PORT|--upstream-port|8080|
|METRICS_ADDRESS|--metrics-addr|0.0.0.0|
|METRICS_PORT|--metrics-port|8082|
|CONNECT_TIMEOUT|--connect-timeout|0.25s|
|HOSTNAME|--hostname|localhost|
|CERT_DAYS|--cert-days|365|
|CERT_RSABITS|--cert-rsa-bits|4096|
|CERT_FILE|--cert-file|/home/envoy/server.crt|
|KEY_FILE|--key-file|/home/envoy/server.key|

