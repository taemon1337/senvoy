SHELL=/bin/bash
IMAGE=taemon1337/senvoy
VERSION=1.0.8
DOM=certauth.cryptomix.com
TESTURL=https://${DOM}/json
CERTS=/var/run/envoy/certs
CAFILE=${CERTS}/server.crt
CERT_FILE=${CERTS}/server.crt
KEY_FILE=${CERTS}/server.key

build:
	docker build -t ${IMAGE}:${VERSION} .

push:
	docker push ${IMAGE}:${VERSION}

sni:
	docker run --rm -it -p 443:9443 -p 80:8080 -e LISTEN_PORT=9443 ${IMAGE}:${VERSION} \
		--sni-route ${DOM}=${DOM} \
		--log /dev/stdout \
		--log-level debug

tls:
	docker run --rm -it -p 443:9443 -p 80:8080 -e LISTEN_PORT=9443 ${IMAGE}:${VERSION} \
		--tls-route ${DOM}=${DOM} \
		--tls-route-config ${DOM}=default \
		--tls-upstream-config ${DOM}=default \
		--tls-config-cert default=${CERT_FILE} \
		--tls-config-key default=${KEY_FILE} \
		--tls-config-insecure default \
		--tls-config-upstream-tls default \
		--tls-config-upstream-health-port default=8082 \
		--tls-config-upstream-health-addr default=127.0.0.1 \
		--log /dev/stdout \
		--log-level debug

forward:
	docker run --rm -it -p 443:9443 -p 80:8080 -e LISTEN_PORT=9443 ${IMAGE}:${VERSION} \
		--http-forward-proxy \
		--sni-forward-proxy \
		--log /dev/stdout \
		--log-level debug

static:
	docker run --rm -it -p 443:9443 -p 80:8080 -e LISTEN_PORT=9443 ${IMAGE}:${VERSION} \
		--http-forward-proxy \
		--sni-forward-proxy \
		--tls-route ${DOM}=${DOM} \
		--tls-route-config ${DOM}=default \
		--tls-config-cert default=${CERT_FILE} \
		--tls-config-key default=${KEY_FILE} \
		--tls-config-insecure default \
		--sni-route github.com=localhost:8443 \
		--log /dev/stdout \
		--log-level debug

