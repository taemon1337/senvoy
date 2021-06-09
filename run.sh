#!/bin/bash

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
    --upstream-addr)          The upstream address to forward traffic to (do not include port, use --upstream-port for port)
    --upstream-port)          The port to forward traffic to
    --metrics-addr)           The address to serve Envoy admin metrics from
    --metrics-port)           The port to serve Envoy admin metrics from
    --connect-timeout)        The amount of time '0.25s' to wait for upstream to connect
    --cert-file)              The certificate file to serve TLS using
    --key-file)               The key file matching the --cert-file
    --cert-days)              The number of days to make the self-signed cert for
    --cert-rsa-bits)          The number of rsa bits to use in the self-signed cert
    --cert-subject)           The certificate subject to use in the self-signed cert
    --hostname)               The hostname to use in the CN of the self-signed cert
  ENVOY_OPTIONS:
    Any additional arguments not matching an above option will be passed to the Envoy entrypoint.
EOF
}

_gencerts() {
  CERT_SUBJECT="/CN=${HOSTNAME}"
  openssl req -x509 -newkey rsa:$CERT_RSABITS -subj $CERT_SUBJECT -sha256 -nodes -keyout $KEY_FILE -out $CERT_FILE -days $CERT_DAYS
}

_config() {
  envsubst < ${ENVOY_TEMPLATE} > ${ENVOY_CONFIG}
}

_start() {
  bash $ENTRYPOINT -c ${ENVOY_CONFIG} ${@}
}

_main() {
  echo "[CERT] Generating self-signed certificates..."
  _gencerts

  echo "[CERT] Generated the following certificate"
  cat ${CERT_FILE} | openssl x509 -noout -text

  echo "[CONFIG] Generating envoy config ${ENVOY_CONFIG}..."
  _config

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
      ENVOY_TEMPLATE=$2
      shift
      shift
      ;; 
    --envoy-config)
      ENVOY_CONFIG=$2
      shift
      shift
      ;;
    --listen-addr)
      LISTEN_ADDR=$2
      shift
      shift
      ;;
    --listen-port)
      LISTEN_PORT=$2
      shift
      shift
      ;;
    --upstream-addr)
      UPSTREAM_ADDR=$2
      shift
      shift
      ;;
    --upstream-port)
      UPSTREAM_PORT=$2
      shift
      shift
      ;;
    --metrics-addr)
      METRICS_ADDR=$2
      shift
      shift
      ;;
    --metrics-port)
      METRICS_PORT=$2
      shift
      shift
      ;;
    --connect-timeout)
      CONNECT_TIMEOUT=$2
      shift
      shift
      ;;
    --cert-file)
      CERT_FILE=$2
      shift
      shift
      ;;
    --key-file)
      KEY_FILE=$2
      shift
      shift
      ;;
    --cert-days)
      CERT_DAYS=$2
      shift
      shift
      ;;
    --cert-rsa-bits)
      CERT_RSABITS=$2
      shift
      shift
      ;;
    --cert-subject)
      CERT_SUBJECT=$2
      shift
      shift
      ;;
    --hostname)
      HOSTNAME=$2
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


