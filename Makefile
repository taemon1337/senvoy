SHELL=/bin/bash
IMAGE=taemon1337/senvoy
VERSION=1.0.0

build:
	docker build -t ${IMAGE}:${VERSION} .

push:
	docker push ${IMAGE}:${VERSION}

run:
	docker run --rm -it ${IMAGE}:${VERSION} --upstream-addr upstream.local --hostname foo.bar --cert-days 3650 --allow-san foo.bar --allow-san-matcher contains
