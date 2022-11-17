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

LISTEN_ADDRESS=${LISTEN_ADDRESS:-"0.0.0.0"}
LISTEN_PORT=${LISTEN_PORT:-"8443"}
LISTEN_HTTP_ADDRESS=${LISTEN_HTTP_ADDRESS:-"0.0.0.0"}
LISTEN_HTTP_PORT=${LISTEN_HTTP_PORT:-"8080"}
HTTP_FORWARD_PROXY=${HTTP_FORWARD_PROXY:-""}
SNI_FORWARD_PROXY=${SNI_FORWARD_PROXY:-""}
SNI_FORWARD_PROXY_PORT=${SNI_FORWARD_PROXY_PORT:-"443"}

SNI_ROUTES=()
SNI_ROUTE_DOMAINS=()
TLS_ROUTES=()
TLS_ROUTE_DOMAINS=()

TLS_ROUTES_CONFIGS=()
TLS_UPSTREAM_CONFIGS=()
TLS_CONFIG_CAS=()
TLS_CONFIG_CERTS=()
TLS_CONFIG_KEYS=()
TLS_CONFIG_KEY_PASSES=()
TLS_CONFIG_INSECURES=()
TLS_CONFIG_UPSTREAM_INSECURES=()
TLS_CONFIG_UPSTREAM_TLS=()
TLS_CONFIG_UPSTREAM_SNI=()
TLS_INSPECTOR=""

LOGPATH=/dev/null

_help() {
  cat << EOF
  USAGE: $0 <options> <envoy-options>
  DESCRIPTION:
    This script is a wrapper around envoy's default entrypoint.
  OPTIONS:
    -h|--help)                Display this help menu
    --listen-addr)            The socket address to listen on (do not include port, use --listen-port for port)
    --listen-port)            The port to listen on
    --listen-http-addr)       The address to listen for/proxy HTTP traffic on (default is '' and will NOT listen)
    --listen-http-port)       The port to listen for/proxy HTTP traffic on
    --http-forward-proxy)     If set, forward HTTP traffic transparently to its DNS resolved upstream address
    --sni-forward-proxy)      If set, forward TLS traffic via its SNI (servername) to its DNS resolved upstream address
    --sni-forward-proxy-port) The upstream port to forward dynamically resolved SNI traffic (default 443)
    --sni-route)              Create a static TLS passthrough route based on the SNI (i.e. <servername>=upstream:6443)
    --sni-route-domain)       Add an additional servername to accept traffic on this servername for this SNI route.
    --tls-route)              Create a static TLS terminating route (i.e. <servername>=upstream:8443)
    --tls-route-domain)       Add an additional domain name to accept traffic on this domain for this tls route.
    --tls-route-config)       Use a TLS config for a particular route by its name (i.e. --tls-route-config <servername>=<name>)
    --tls-upstream-config)    Use a TLS config for a particular route upstream by its name (i.e. --tls-upstream-config <route>=<name>)
    --tls-config-cert)              Set the cert file for a TLS config (i.e. <name>=/etc/tls/pki/cert.crt)
    --tls-config-key)               Set the key file for a TLS config (i.e. <name>=/etc/tls/pki/cert.key)
    --tls-config-key-pass)          Set the password to decrypt a TLS key (i.e. <name>=password)
    --tls-config-ca)                Set the CA file for a TLS config (i.e. <name>=/etc/tls/pki/ca.crt)
    --tls-config-insecure)          Do not verify the other side of the TLS connection
    --tls-config-upstream-insecure) Do not verify the upstream server
    --tls-config-upstream-tls)      Use TLS for the upstream protocol (this only applies to upstream connections)
    --tls-config-upstream-sni)      Use this SNI when connecting to upstream servers (this only applies to upstream connections)
    --dryrun                        Print the rendered config and exit
    --log                           Set logs to output to specific path (i.e. /dev/stdout, /dev/stderr)

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

_routify() {
  local routetype="$1" # tls or sni
  local route="$2"
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

  if [[ "${routetype}" == "sni" ]]; then

    # not exactly sure if this is needed or how it works as sni port is already in the upstream
    for rt in "${TLS_ROUTE_CONFIGS[@]}"; do
      if [[ "$(echo "${rt}" | awk -F= '{print $1}' | tr -d '.*')" == "${id}" ]]; then
        echo "  sni_port: $(echo "${rt}" | awk -F= '{print $2}')"
      fi
    done

    if [[ "${#SNI_ROUTE_DOMAINS[@]}" -gt 0 ]]; then
      local domains=()
      for rt in "${SNI_ROUTE_DOMAINS[@]}"; do
        if [[ "$(echo "${rt}" | awk -F= '{print $1}' | tr -d '.*')" == "${id}" ]]; then
          domains+=("$(echo "${rt}" | awk -F= '{print $2}')")
        fi
      done
      if [[ "${#domains}" -gt 0 ]]; then
        echo "  sni_domains:"
        for dn in "${domains[@]}"; do
          echo "  - ${dn}"
        done
      fi
    fi

  fi

  if [[ "${routetype}" == "tls" ]]; then
    for rt in "${TLS_ROUTE_CONFIGS[@]}"; do
      if [[ "$(echo "${rt}" | awk -F= '{print $1}' | tr -d '.*')" == "${id}" ]]; then
        _tls_configify "$(echo "${rt}" | awk -F= '{print $2}')" route
      fi
    done

    for rt in "${TLS_UPSTREAM_CONFIGS[@]}"; do
      if [[ "$(echo "${rt}" | awk -F= '{print $1}' | tr -d '.*')" == "${id}" ]]; then
        _tls_configify "$(echo "${rt}" | awk -F= '{print $2}')" upstream
      fi
    done

    if [[ "${#TLS_ROUTE_DOMAINS[@]}" -gt 0 ]]; then
      local domains=()
      for rt in "${TLS_ROUTE_DOMAINS[@]}"; do
        if [[ "$(echo "${rt}" | awk -F= '{print $1}' | tr -d '.*')" == "${id}" ]]; then
          domains+=("$(echo "${rt}" | awk -F= '{print $2}')")
        fi
      done
      if [[ "${#domains}" -gt 0 ]]; then
        echo "  tls_domains:"
        for dn in "${domains[@]}"; do
          echo "  - ${dn}"
        done
      fi
    fi

  fi
}

_tls_configify() {
  local id="$1"
  local prefix="$2"

  for rt in "${TLS_CONFIG_CAS[@]}"; do
    if [[ "$(echo "${rt}" | awk -F= '{print $1}' | tr -d '.*')" == "${id}" ]]; then
      echo "  ${prefix}_ca: $(echo "${rt}" | awk -F= '{print $2}')"
    fi
  done

  for rt in "${TLS_CONFIG_CERTS[@]}"; do
    if [[ "$(echo "${rt}" | awk -F= '{print $1}' | tr -d '.*')" == "${id}" ]]; then
      echo "  ${prefix}_cert: $(echo "${rt}" | awk -F= '{print $2}')"
    fi
  done

  for rt in "${TLS_CONFIG_KEYS[@]}"; do
    if [[ "$(echo "${rt}" | awk -F= '{print $1}' | tr -d '.*')" == "${id}" ]]; then
      echo "  ${prefix}_key: $(echo "${rt}" | awk -F= '{print $2}')"
    fi
  done

  for rt in "${TLS_CONFIG_KEY_PASSES[@]}"; do
    if [[ "$(echo "${rt}" | awk -F= '{print $1}' | tr -d '.*')" == "${id}" ]]; then
      echo "  ${prefix}_key_pass: $(echo "${rt}" | awk -F= '{print $2}')"
    fi
  done

  for rt in "${TLS_CONFIG_INSECURES[@]}"; do
    if [[ "$(echo "${rt}" | awk -F= '{print $1}' | tr -d '.*')" == "${id}" ]]; then
      echo "  ${prefix}_insecure: true"
    fi
  done

  for rt in "${TLS_CONFIG_UPSTREAM_INSECURES[@]}"; do
    if [[ "$(echo "${rt}" | awk -F= '{print $1}' | tr -d '.*')" == "${id}" ]]; then
      echo "  upstream_insecure: true" # this is an upstream only config
    fi
  done

  for rt in "${TLS_CONFIG_UPSTREAM_TLS[@]}"; do
    if [[ "$(echo "${rt}" | awk -F= '{print $1}' | tr -d '.*')" == "${id}" ]]; then
      echo "  upstream_tls: true" # this is an upstream only config so no prefix used
    fi
  done

  for rt in "${TLS_CONFIG_UPSTREAM_SNI[@]}"; do
    if [[ "$(echo "${rt}" | awk -F= '{print $1}' | tr -d '.*')" == "${id}" ]]; then
      echo "  upstream_sni: $(echo "${rt}" | awk -F= '{print $2}')" # upstream only setting
    fi
  done
}

# print all env vars as key: value yaml
_datayaml() {
  for var in $(compgen -e); do
    if [[ "${var}" != "SNI_ROUTES" ]] && [[ "${var}" != "TLS_ROUTES" ]] && [[ ! -z "${!var}" ]]; then
      echo "${var}: ${!var}"
    fi
  done

  if [[ "${#SNI_ROUTES}" -gt 0 ]] || [[ "${#TLS_ROUTES}" -gt 0 ]] || [[ -n "${SNI_FORWARD_PROXY}" ]]; then
    echo "TLS_INSPECTOR: true"
  fi

  if [[ "${#SNI_ROUTES}" -gt 0 ]]; then
    echo "SNI_ROUTES:"
    for rt in "${SNI_ROUTES[@]}"; do
      _routify sni "${rt}"
    done
  fi

  if [[ "${#TLS_ROUTES}" -gt 0 ]]; then
    echo "TLS_ROUTES:"
    for rt in "${TLS_ROUTES[@]}"; do
      _routify tls "${rt}"
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
    --connect-timeout)
      CONNECT_TIMEOUT="$2"
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
    --http-forward-proxy)
      HTTP_FORWARD_PROXY=1
      shift
      ;;
    --sni-forward-proxy)
      SNI_FORWARD_PROXY=1
      shift
      ;;
    --sni-forward-proxy-port)
      SNI_FORWARD_PROXY_PORT="$2"
      shift
      shift
      ;;
    --sni-route)
      SNI_ROUTES+=("$2")
      shift
      shift
      ;;
    --sni-route-domain)
      SNI_ROUTE_DOMAINS+=("$2")
      shift
      shift
      ;;
    --tls-route)
      TLS_ROUTES+=("$2")
      shift
      shift
      ;;
    --tls-route-domain)
      TLS_ROUTE_DOMAINS+=("$2")
      shift
      shift
      ;;
    --tls-route-config)
      TLS_ROUTE_CONFIGS+=("$2")
      shift
      shift
      ;;
    --tls-upstream-config)
      TLS_UPSTREAM_CONFIGS+=("$2")
      shift
      shift
      ;;
    --tls-config-ca)
      TLS_CONFIG_CAS+=("$2")
      shift
      shift
      ;;
    --tls-config-cert)
      TLS_CONFIG_CERTS+=("$2")
      shift
      shift
      ;;
    --tls-config-key)
      TLS_CONFIG_KEYS+=("$2")
      shift
      shift
      ;;
    --tls-config-key-pass)
      TLS_CONFIG_KEY_PASSES+=("$2")
      shift
      shift
      ;;
    --tls-config-insecure)
      TLS_CONFIG_INSECURES+=("$2")
      shift
      shift
      ;;
    --tls-config-upstream-insecure)
      TLS_CONFIG_UPSTREAM_INSECURES+=("$2")
      shift
      shift
      ;;
    --tls-config-upstream-tls)
      TLS_CONFIG_UPSTREAM_TLS+=("$2")
      shift
      shift
      ;;
    --tls-config-upstream-sni)
      TLS_CONFIG_UPSTREAM_SNI+=("$2")
      shift
      shift
      ;;
    --hostname)
      HOSTNAME="$2"
      shift
      shift
      ;;
    --metrics-port)
      METRICS_PORT="$2"
      shift
      shift
      ;;
    --metrics-addr)
      METRICS_ADDRESS="$2"
      shift
      shift
      ;;
    --log)
      LOGPATH="$2"
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


