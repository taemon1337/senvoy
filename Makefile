SHELL=/bin/bash
IMAGE=taemon1337/senvoy
VERSION=1.0.6
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

run:
	docker run --rm -it ${IMAGE}:${VERSION} --upstream-addr upstream.local --hostname foo.bar --cert-days 3650 --allow-san foo.bar --allow-san-matcher contains

http:
	docker run --rm -it ${IMAGE}:${VERSION} --upstream-addr upstream.local --hostname foo.bar --cert-days 3650 --allow-san foo.bar --allow-san-matcher contains --listen-http-addr 0.0.0.0 --upstream-http-addr github.com

sni:
	docker run --rm -it -p 443:9443 -p 80:8080 -e LISTEN_PORT=9443 ${IMAGE}:${VERSION} \
		--sni \
		--log /dev/stdout \
		--log-level debug \
		--http-forward-proxy \
		--route ${DOM}=${DOM} \
		--route-upstream-tls ${DOM} \
		--route-upstream-ca ${DOM}=${CAFILE} \
		--route-upstream-cert ${DOM}=${CERT_FILE} \
		--route-upstream-key ${DOM}=${KEY_FILE} \
		--route-tls ${DOM} \
		--route-cert ${DOM}=${CERT_FILE} \
		--route-key ${DOM}=${KEY_FILE} \
		--route-require-client-cert ${DOM}

sni-router:
	docker run --rm -it -e LISTEN_PORT=9443 ${IMAGE}:${VERSION} --sni-router --route github.com=localhost:8443 --route foo.com=1.2.3.4:1234 --route in.com=out.com --route *.local=default.local --route *.star=star.local
