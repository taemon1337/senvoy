SHELL=/bin/bash
IMAGE=taemon1337/senvoy
VERSION=1.0.2

build:
	docker build -t ${IMAGE}:${VERSION} .

push:
	docker push ${IMAGE}:${VERSION}

run:
	docker run --rm -it ${IMAGE}:${VERSION} --upstream-addr upstream.local --hostname foo.bar --cert-days 3650 --allow-san foo.bar --allow-san-matcher contains

sni:
	docker run --rm -it -e LISTEN_PORT=9443 ${IMAGE}:${VERSION} --sni

sni-router:
	docker run --rm -it -e LISTEN_PORT=9443 ${IMAGE}:${VERSION} --sni-router --route github.com=localhost:8443 --route foo.com=1.2.3.4:1234 --route in.com=out.com --route *.local=default.local --route *.star=star.local
