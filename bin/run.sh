#!/bin/bash

ENVOY_HOME=${ENVOY_HOME:-/var/run/envoy}
ENVOY_CERTS=${ENVOY_CERTS:-/var/run/envoy/certs}
ENVOY_CONFIG=${ENVOY_CONFIG:-/var/run/envoy/envoy.yaml}
ENVOY_TEMPLATE=${ENVOY_TEMPLATE:-/usr/local/src/envoy.tmpl}
DATA_FILE=${DATA_FILE:-/usr/local/src/data.yaml}
CERT_FILE=${CERT_FILE:-"${ENVOY_CERTS}/server.crt"}
KEY_FILE=${KEY_FILE:-"${ENVOY_CERTS}/server.key"}
CA_FILE=${CA_FILE:-"${ENVOY_CERTS}/server.crt"}
REQUIRE_CLIENT_CERT=${REQUIRE_CLIENT_CERT:-false}
LISTEN_ADDRESS=${LISTEN_ADDRESS:-0.0.0.0}
LISTEN_PORT=${LISTEN_PORT:-8443}
LISTEN_HTTP_ADDRESS=${LISTEN_HTTP_ADDRESS:-0.0.0.0}
LISTEN_HTTP_PORT=${LISTEN_HTTP_PORT:-80}
HTTP_FORWARD_PROXY=${HTTP_FORWARD_PROXY:-""}
UPSTREAM_HTTP_ADDRESS=${UPSTREAM_HTTP_ADDRESS:-127.0.0.1}
UPSTREAM_HTTP_PORT=${UPSTREAM_HTTP_PORT:-80}
UPSTREAM_ADDRESS=${UPSTREAM_ADDRESS:-127.0.0.1}
UPSTREAM_PORT=${UPSTREAM_PORT:-8080}
UPSTREAM_SNI=${UPSTREAM_SNI:-""}
UPSTREAM_TLS=${UPSTREAM_TLS:-""}
PATH_PREFIX=${PATH_PREFIX:-"/"}
PREFIX_REWRITE=${PREFIX_REWRITE:-"/"}
METRICS_ADDRESS=${METRICS_ADDRESS:-0.0.0.0}
METRICS_PORT=${METRICS_PORT:-8082}
CONNECT_TIMEOUT=${CONNECT_TIMEOUT:-"0.25s"}
HOSTNAME=${HOSTNAME:-localhost}
CERT_DAYS=${CERT_DAYS:-365}
CERT_RSABITS=${CERT_RSABITS:-4096}
ALLOW_SAN=${ALLOW_SAN:-""}
ALLOW_SAN_MATCHER=${ALLOW_SAN_MATCHER:-exact}
SNI_TEMPLATE=/usr/local/src/sni.tmpl
TLS_TEMPLATE=/usr/local/src/tls.tmpl
SNI_ROUTER_TEMPLATE=/usr/local/src/sni-router.tmpl
ROUTES=() # sni routes 'i.e. <server-name>=<upstream_host:port>'
ROUTES_SNI_PORTS=() # i.e. <server-name>=8443
ROUTES_UPSTREAM_TLS=() # i.e. <server-name>
ROUTES_UPSTREAM_INSECURE=() # i.e. <server-name>
ROUTES_UPSTREAM_CAS=() # i.e. <server-name>=/etc/ssl/tls/ca.crt
ROUTES_UPSTREAM_CERTS=() # i.e. <server-name>=/etc/ssl/tls/cert.crt
ROUTES_UPSTREAM_KEYS=() # i.e. <server-name>=/etc/ssl/tls/cert.key
ROUTES_UPSTREAM_PASSWORDS=() # i.e. <server-name>=priv-key-pass
ROUTES_DOWNSTREAM_TLS=()
ROUTES_DOWNSTREAM_MUTUAL=()
ROUTES_DOWNSTREAM_INSECURE=()
ROUTES_DOWNSTREAM_CAS=()
ROUTES_DOWNSTREAM_CERTS=()
ROUTES_DOWNSTREAM_KEYS=()
ROUTES_DOWNSTREAM_PASSWORDS=()
DRYRUN=${DRYRUN:-""}
LOGPATH=/dev/null

_help() {
  cat << EOF
  USAGE: $0 <options> <envoy-options>
  DESCRIPTION:
    This script is a wrapper around envoy's default entrypoint.
  OPTIONS:
    -h|--help)                Display this help menu
    --envoy-template)         Override the TLS sidecar envoy template (a yaml with ENV vars that get envsubst'ed)
    --envoy-config)           The path to render the envoy template into that envoy will use
    --listen-addr)            The socket address to listen on (do not include port, use --listen-port for port)
    --listen-port)            The port to listen on
    --listen-http-addr)       The address to listen for/proxy HTTP traffic on (default is '' and will NOT listen)
    --listen-http-port)       The port to listen for/proxy HTTP traffic on
    --http-forward-proxy)     If set, use http forward proxy same as --sni to forward http traffic to
    --upstream-http-addr)     The address to proxy HTTP traffic to
    --upstream-http-port)     The port to proxy HTTP traffic to
    --upstream-addr)          The upstream address to forward traffic to (do not include port, use --upstream-port for port)
    --upstream-port)          The port to forward traffic to
    --upstream-sni)           Set the SNI in the upstream tls connection
    --upstream-tls)           Set to connect to upstream using tls
    --path-prefix)            The incoming request path to match prefix on (default /)
    --prefix-rewrite)         The upstream request path to rewrite the prefix to (default /)
    --metrics-addr)           The address to serve Envoy admin metrics from
    --metrics-port)           The port to serve Envoy admin metrics from
    --connect-timeout)        The amount of time '0.25s' to wait for upstream to connect
    --cert-file)              The certificate file to serve TLS using
    --key-file)               The key file matching the --cert-file
    --ca-file                 The CA file to validate client connections against (for mutual TLS)
    --require-client-cert     If this flag is set (no value) then require the tls client to provide a TLS client cert
    --allow-san               Only allow Subject Alternate Names (SAN) matching this value to connect
    --allow-san-matcher       The type of matcher to use for the SAN, default is exact, can be contains, prefix, suffix (any envoy string matcher)
    --cert-days)              The number of days to make the self-signed cert for
    --cert-rsa-bits)          The number of rsa bits to use in the self-signed cert
    --cert-subject)           The certificate subject to use in the self-signed cert
    --hostname)               The hostname to use in the CN of the self-signed cert
    --sni-router)             Alias for '--envoy-template sni-router.tmpl'
    --sni)                    Alias for '--envoy-template sni.tmpl'
    --sni-port)               With dynamic SNI routes you can still set the upstream port
                              i.e. --sni-port servername=8443
    --tls)                    Alias for '--envoy-template tls.tmpl'
    --route)                  When using --sni, --route maps the servername to upstream host:port
                              i.e. --route incoming.com=upstream.local:8443
    --route-upstream-tls)     Enable TLS for upstream routes
                              i.e. --route-upstream-tls incoming.com will use upstream tls for incoming.com route
    --route-upstream-insecure Do not verify the CA of the upstream server
                              i.e. --route-upstream-insecure incoming.com
    --route-upstream-ca)      Set the filepath to the upstream CA file to verify upstream server
                              i.e. --route-upstream-ca incoming.com=/etc/tls/certs/ca.crt
    --route-upstream-cert)    Set the filepath to the upstream cert file to connect with
                              i.e. --route-upstream-ca incoming.com=/etc/tls/certs/cert.crt
    --route-upstream-key)     Set the filepath to the upstream key file to connect with
                              i.e. --route-upstream-ca incoming.com=/etc/tls/certs/cert.key
    --route-upstream-pass)    The password to decrypt the upstream key with
                              i.e. --route-upstream-pass incoming.com=theprivkeypass
    --route-tls)              Enable TLS termination of the incoming connection
    --route-require-client-cert) Require the client to provide TLS client cert authentication
    --route-ca)               Set the CA to verify the incoming client against
    --route-cert)             Set the TLS server certificate to provide clients for this route
    --route-key)              The matching TLS server certificate key for this route
    --route-pass)             The TLS server certificate key password to decrypt the key with
    --dryrun                  Print the rendered config and exit
    --log                     Set logs to output to specific path (i.e. /dev/stdout, /dev/stderr)

  ENVOY_OPTIONS:
    Any additional arguments not matching an above option will be passed to the Envoy entrypoint.
EOF
}

_gencerts() {
  local cert_file=$ENVOY_CERTS/server.crt
  local key_file=$ENVOY_CERTS/server.key
  local ca_file=$ENVOY_CERTS/ca.crt

  mkdir -p $ENVOY_CERTS
  # We must copy the certs so they have correct envoy permissions (since run.sh runs as root but proxy runs as envoy)

  if [ -f "${CA_FILE}" ]; then
    echo "[CA] Copying $CA_FILE to $ca_file"
    cat ${CA_FILE} > $ca_file
    export CA_FILE=$ca_file
  fi

  if [ -f "${CERT_FILE}" ]; then
    echo "[CERT] Copying $CERT_FILE to $cert_file"
    cat ${CERT_FILE} > $cert_file
    export CERT_FILE=$cert_file
  fi

  if [ -f "${KEY_FILE}" ]; then
    echo "[KEY] Copying $KEY_FILE to $key_file"
    cat ${CERT_FILE} > $key_file
    export CERT_FILE=$key_file
  fi

  if [[ -f "${CERT_FILE}" || -f "${KEY_FILE}" ]]; then
    echo "[CERT] Certificate: ${CERT_FILE}, Key: ${KEY_FILE}, CA: ${CA_FILE}"
  else
    if [ -z "${CERT_SUBJECT}" ]; then CERT_SUBJECT="/CN=$HOSTNAME" ; fi
    if [ -z "${CERT_SAN}" ]; then CERT_SAN=$HOSTNAME ; fi
    echo "[CERT] Generate Self Signed: Subj: $CERT_SUBJECT, SAN: $CERT_SAN"

    cat <<EOF > /tmp/san.cnf
[ req ]
default_bits       = $CERT_RSABITS
distinguished_name = req_distinguished_name
req_extensions     = san
[ req_distinguished_name ]
commonName                 = $CERT_SUBJECT 
[ san ]
subjectAltName = @alt_names
[alt_names]
DNS.1   = localhost
DNS.2   = $CERT_SAN
EOF

    openssl req -x509 \
    -newkey rsa:$CERT_RSABITS \
    -subj $CERT_SUBJECT \
    -sha256 -nodes \
    -keyout $KEY_FILE \
    -out $CERT_FILE \
    -days $CERT_DAYS \
    -extensions san \
    -config /tmp/san.cnf

    # https://github.com/istio/istio/issues/22530
    echo "" >> "${CERT_FILE}"

    echo "[CERT] Generated the following certificate"
    cat ${CERT_FILE} | openssl x509 -noout -text
  fi

  if [ ! -f "${ca_file}" ]; then
    echo "[CA] Using $CERT_FILE as CA"
    cat ${cert_file} > ${ca_file}
  fi

  # Overwrite the global vars with the generated/copied readable files
  CERT_FILE=$cert_file
  KEY_FILE=$key_file
  CA_FILE=$ca_file
}

_validate() {
  if [ -n "$ALLOW_SAN" ]; then
    echo "[INFO] Enabling --require-client-cert as it is required in order to validate SAN since ALLOW_SAN=$ALLOW_SAN"
    export REQUIRE_CLIENT_CERT="true"
  fi
}

# turn sni=host:port into sni yaml
_routify() {
  local route="$1"
  local servername=$(echo "${route}" | awk -F= '{print $1}')
  local id=$(echo "${servername}" | tr -d '.*')
  local upstream=$(echo "${route}" | awk -F= '{print $2}')
  local upstream_host=$(echo "${upstream}" | awk -F: '{print $1}')
  local upstream_port=$(echo "${upstream}" | awk -F: '{print $2}')
  if [[ "${upstream_port}" == "" ]]; then upstream_port="443"; fi
  if [[ "${id}" == "" ]]; then id="wildcard"; fi
  echo "- id: ${id}"
  echo "  servername: \"${servername}\""
  echo "  upstream_addr: ${upstream_host}"
  echo "  upstream_port: ${upstream_port}"

  for rt in "${ROUTES_SNI_PORTS[@]}"; do
    if [[ "$(echo "${rt}" | awk -F= '{print $1}' | tr -d '.*')" == "${id}" ]]; then
      echo "  sni_port: $(echo "${rt}" | awk -F= '{print $2}')"
    fi
  done

  for rt in "${ROUTES_UPSTREAM_TLS[@]}"; do
    if [[ "$(echo "${rt}" | awk -F= '{print $1}' | tr -d '.*')" == "${id}" ]]; then
      echo "  upstream_tls: true"
    fi
  done
  for rt in "${ROUTES_UPSTREAM_INSECURE[@]}"; do
    if [[ "$(echo "${rt}" | awk -F= '{print $1}' | tr -d '.*')" == "${id}" ]]; then
      echo "  upstream_tls_insecure: true"
    fi
  done
  for rt in "${ROUTES_UPSTREAM_CAS[@]}"; do
    if [[ "$(echo "${rt}" | awk -F= '{print $1}' | tr -d '.*')" == "${id}" ]]; then
      echo "  upstream_ca: $(echo "${rt}" | awk -F= '{print $2}')"
    fi
  done
  for rt in "${ROUTES_UPSTREAM_CERTS[@]}"; do
    if [[ "$(echo "${rt}" | awk -F= '{print $1}' | tr -d '.*')" == "${id}" ]]; then
      echo "  upstream_cert: $(echo "${rt}" | awk -F= '{print $2}')"
    fi
  done
  for rt in "${ROUTES_UPSTREAM_KEYS[@]}"; do
    if [[ "$(echo "${rt}" | awk -F= '{print $1}' | tr -d '.*')" == "${id}" ]]; then
      echo "  upstream_key: $(echo "${rt}" | awk -F= '{print $2}')"
    fi
  done
  for rt in "${ROUTES_UPSTREAM_PASSWORDS[@]}"; do
    if [[ "$(echo "${rt}" | awk -F= '{print $1}' | tr -d '.*')" == "${id}" ]]; then
      echo "  upstream_key_pass: $(echo "${rt}" | awk -F= '{print $2}')"
    fi
  done

  for rt in "${ROUTES_DOWNSTREAM_TLS[@]}"; do
    if [[ "$(echo "${rt}" | awk -F= '{print $1}' | tr -d '.*')" == "${id}" ]]; then
      echo "  route_tls: true"
    fi
  done
  for rt in "${ROUTES_DOWNSTREAM_MUTUAL[@]}"; do
    if [[ "$(echo "${rt}" | awk -F= '{print $1}' | tr -d '.*')" == "${id}" ]]; then
      echo "  route_mutual: true"
    fi
  done
  for rt in "${ROUTES_DOWNSTREAM_CAS[@]}"; do
    if [[ "$(echo "${rt}" | awk -F= '{print $1}' | tr -d '.*')" == "${id}" ]]; then
      echo "  route_ca: $(echo "${rt}" | awk -F= '{print $2}')"
    fi
  done
  for rt in "${ROUTES_DOWNSTREAM_CERTS[@]}"; do
    if [[ "$(echo "${rt}" | awk -F= '{print $1}' | tr -d '.*')" == "${id}" ]]; then
      echo "  route_cert: $(echo "${rt}" | awk -F= '{print $2}')"
    fi
  done
  for rt in "${ROUTES_DOWNSTREAM_KEYS[@]}"; do
    if [[ "$(echo "${rt}" | awk -F= '{print $1}' | tr -d '.*')" == "${id}" ]]; then
      echo "  route_key: $(echo "${rt}" | awk -F= '{print $2}')"
    fi
  done
  for rt in "${ROUTES_DOWNSTREAM_PASSWORDS[@]}"; do
    if [[ "$(echo "${rt}" | awk -F= '{print $1}' | tr -d '.*')" == "${id}" ]]; then
      echo "  route_key_pass: $(echo "${rt}" | awk -F= '{print $2}')"
    fi
  done
}

# print all env vars as key: value yaml
_datayaml() {
  for var in $(compgen -e); do
    if [[ "${var}" != "ROUTES" ]] && [[ ! -z "${!var}" ]]; then
      echo "${var}: ${!var}"
    fi
  done

  if [[ "${ENVOY_TEMPLATE}" == "${SNI_ROUTER_TEMPLATE}" ]] || \
     [[ "${ENVOY_TEMPLATE}" == "${SNI_TEMPLATE}" ]] || \
     [[ "${ENVOY_TEMPLATE}" == "${TLS_TEMPLATE}" ]] ; then
    echo "ROUTES:"
    for rt in "${ROUTES[@]}"; do
      _routify "${rt}"
    done
  fi
}

_config() {
  if ! command -v mustache &> /dev/null; then
    echo "[ERROR] mustache command could not be found"
    exit 1
  fi

  mustache $DATA_FILE $ENVOY_TEMPLATE > $ENVOY_CONFIG
}

_start() {
  chown -R envoy. ${ENVOY_CERTS}
  bash $ENTRYPOINT -c ${ENVOY_CONFIG} ${@}
}

_main() {
  mkdir -p $ENVOY_HOME

  _gencerts
  _validate

  echo "Writing data variables to $DATA_FILE"
  _datayaml > $DATA_FILE
  cat $DATA_FILE

  echo "[CONFIG] Generating envoy config ${ENVOY_CONFIG}..."
  _config
  cat $ENVOY_CONFIG

  if [[ "${DRYRUN}" == "1" ]]; then
    exit 0
  fi

  echo "[START] ${@}"
  _start ${@}
}

args=()
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -h|--help)
      _help
      exit 0
      ;;
    --envoy-template)
      ENVOY_TEMPLATE="$2"
      shift
      shift
      ;;
    --sni)
      ENVOY_TEMPLATE="${SNI_TEMPLATE}"
      shift
      ;;
    --tls)
      ENVOY_TEMPLATE="${TLS_TEMPLATE}"
      shift
      ;;
    --sni-router)
      ENVOY_TEMPLATE="${SNI_ROUTER_TEMPLATE}"
      shift
      ;;
    --route)
      ROUTES+=("$2")
      shift
      shift
      ;;
    --sni-port)
      ROUTES_SNI_PORTS+=("$2")
      shift
      shift
      ;;
    --route-tls)
      ROUTES_DOWNSTREAM_TLS+=("$2")
      shift
      shift
      ;;
    --route-require-client-cert)
      ROUTES_DOWNSTREAM_MUTUAL+=("$2")
      shift
      shift
      ;;
    --route-ca)
      ROUTES_DOWNSTREAM_CAS+=("$2")
      shift
      shift
      ;;
    --route-cert)
      ROUTES_DOWNSTREAM_CERTS+=("$2")
      shift
      shift
      ;;
    --route-key)
      ROUTES_DOWNSTREAM_KEYS+=("$2")
      shift
      shift
      ;;
    --route-pass)
      ROUTES_DOWNSTREAM_PASSWORDS+=("$2")
      shift
      shift
      ;;
    --route-upstream-tls)
      ROUTES_UPSTREAM_TLS+=("$2")
      shift
      shift
      ;;
    --route-upstream-insecure)
      ROUTES_UPSTREAM_INSECURE+=("$2")
      shift
      shift
      ;;
    --route-upstream-ca)
      ROUTES_UPSTREAM_CAS+=("$2")
      shift
      shift
      ;;
    --route-upstream-cert)
      ROUTES_UPSTREAM_CERTS+=("$2")
      shift
      shift
      ;;
    --route-upstream-key)
      ROUTES_UPSTREAM_KEYS+=("$2")
      shift
      shift
      ;;
    --route-upstream-pass)
      ROUTES_UPSTREAM_PASSWORDS+=("$2")
      shift
      shift
      ;;
    --envoy-config)
      ENVOY_CONFIG="$2"
      shift
      shift
      ;;
    --data-file)
      DATA_FILE="$2"
      shift
      shift
      ;;
    --listen-addr)
      LISTEN_ADDRESS="$2"
      shift
      shift
      ;;
    --listen-port)
      LISTEN_PORT="$2"
      shift
      shift
      ;;
    --listen-http-addr)
      LISTEN_HTTP_ADDRESS="$2"
      shift
      shift
      ;;
    --listen-http-port)
      LISTEN_HTTP_PORT="$2"
      shift
      shift
      ;;
    --log)
      LOGPATH="$2"
      shift
      shift
      ;;
    --http-forward-proxy)
      HTTP_FORWARD_PROXY="1"
      shift
      ;;
    --upstream-http-addr)
      UPSTREAM_HTTP_ADDRESS="$2"
      shift
      shift
      ;;
    --upstream-http-port)
      UPSTREAM_HTTP_PORT="$2"
      shift
      shift
      ;;
    --upstream-addr)
      UPSTREAM_ADDRESS="$2"
      shift
      shift
      ;;
    --upstream-port)
      UPSTREAM_PORT="$2"
      shift
      shift
      ;;
    --upstream-sni)
      UPSTREAM_SNI="$2"
      shift
      shift
      ;;
    --upstream-tls)
      UPSTREAM_TLS=1
      shift
      ;;
    --path-prefix)
      PATH_PREFIX="$2"
      shift
      shift
      ;;
    --prefix-rewrite)
      PREFIX_REWRITE="$2"
      shift
      shift
      ;;
    --metrics-addr)
      METRICS_ADDRESS="$2"
      shift
      shift
      ;;
    --metrics-port)
      METRICS_PORT="$2"
      shift
      shift
      ;;
    --connect-timeout)
      CONNECT_TIMEOUT="$2"
      shift
      shift
      ;;
    --cert-file)
      CERT_FILE="$2"
      shift
      shift
      ;;
    --dryrun)
      DRYRUN=1
      shift
      ;;
    --key-file)
      KEY_FILE="$2"
      shift
      shift
      ;;
    --ca-file)
      CA_FILE="$2"
      shift
      shift
      ;;
    --require-client-cert)
      REQUIRE_CLIENT_CERT=true
      shift
      ;;
    --allow-san)
      ALLOW_SAN="$2"
      shift
      shift
      ;;
    --allow-san-matcher)
      ALLOW_SAN_MATCHER="$2"
      shift
      shift
      ;;
    --cert-days)
      CERT_DAYS="$2"
      shift
      shift
      ;;
    --cert-rsa-bits)
      CERT_RSABITS="$2"
      shift
      shift
      ;;
    --cert-subject)
      CERT_SUBJECT="$2"
      shift
      shift
      ;;
    --hostname)
      HOSTNAME="$2"
      shift
      shift
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

_main "${args[@]}"


