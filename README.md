# Simple Envoy Proxy

A simple wrapper container around Envoy that eases configuration for traffic routing using the robust Envoy proxy.

## Rationale

The Envoy Proxy is a very robust, well-proven piece of proxy technology and it supports all major protocols, features, bells, whistles, etc.  This is also an issue when being deployed in a simple configuration (such as a TLS sidecar) where you just want a robust and simple proxy up and running fast without the config headache hassel.

This project gives you the best of both worlds, up and running fast with hardened, production ready proxy.

## Examples

See the [examples](./examples) folder for some different docker-compose examples of how to use senvoy.

## Modes

### SNI Forward Proxy

The `--sni-forward-proxy` mode will not terminate TLS connections, but prereads the Servername (SNI) during the TLS handshake and routes traffic based on the DNS resolution of that SNI.

The SNI and HTTP forward proxy modes are very useful for inbound and outbound traffic gateways into environments like Kubernetes.  A senvoy proxy can be configured to receive all traffic via DNS "hijacking" of valid/public domains and the senvoy proxy can route traffic to their valid public domains transparently.

```bash
  docker run --rm -it -p 8443:8443 taemon1337/senvoy:latest --sni-forward-proxy
```

### HTTP Forward Proxy

The `--http-forward-proxy` mode will work just like the `--sni-forward-proxy` but for HTTP traffic.  It will receive HTTP traffic and transparently send it upstream to the DNS hostname resolved.

### SNI Route

The `--sni-route <sni>=<host:port>` mode will also not terminate TLS connections but will route to the provided backend directly.

### TLS Route

The `--tls-route <domain>=<host:port>` will terminate TLS connections and forward traffic to the specified upstream.  This mode includes many additional options for TLS (like `--tls-config-cert` and `--tls-config-upstream-tls`).

If you need self-signed certificates, there are automatically generated ones available for the given `--hostname` at the following locations:

```
CERT_FILE: /var/run/envoy/certs/server.crt
KEY_FILE: /var/run/envoy/certs/server.key
CA_FILE: /var/run/envoy/certs/server.crt (since self-signed)
```

### CLI Options

The TLS connection can be extensively configured by settings up `--tls-config-<option> <config-name>=<config-value>` and then assigning a route to use the config.  See below for the list of possible options for each route type.

#### TLS Route Options
```
--tls-route-config              <route-name>=<config-name>            Assign the tls config to the route
--tls-upstream-config           <route-name>=<config-name>            Assign the tls config to the upstream of the given route
--tls-route-domain              <route-name>=<domain>                 Add domain name for given route
```

#### SNI Route Options
```
--sni-route-domain              <route-name>=<domain>                 Add domain name (via SNI) for given route
```

#### TLS config

```
--tls-config-cert               <config-name>=<path/to/cert/file>     Use the given cert file for TLS authentication (upstream or downstream as assigned)
--tls-config-key                <config-name>=<path/to/key/file>      Use the given key file along with a given cert
--tls-config-ca                 <config-name>=<path/to/ca/file>       Authenticate other side of TLS connection with given CA file
--tls-config-insecure           <config-name>                         Do not verify TLS connection against a CA for incoming connections
--tls-config-upstream-insecure  <config-name>                         Do not verify upstream server against a CA
--tls-config-upstream-tls       <config-name>                         Use TLS for upstream connections (HTTP if not set)
--tls-config-upstream-sni       <config-name>=<sni>                   Use a custom SNI in upstream TLS connections
```


## Docker entrypoint wrapper

The `run.sh` script performs the following steps:

1. Generates self-signed TLS certificates (if the CERT_FILE|--cert-file does not exist)
2. Generates an Envoy static config and writes it to disk
3. Calls the original Envoy docker-entrypoint.sh with the `--config-path <generated-envoy-config>` and any additional options you pass through

