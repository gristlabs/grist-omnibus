PORT = 8484
TEAM = meep

build:
	docker build -t paulfitz/grist:omnibus .

buildwitharch:
	DOCKER_BUILDKIT=1 docker buildx build --platform linux/amd64,linux/arm64 -t paulfitz/grist:omnibus .
	DOCKER_BUILDKIT=1 docker buildx build -t paulfitz/grist:omnibus --load .

run:
	mkdir -p /tmp/omnibus
	docker run --rm --name grist -e URL=http://localhost:$(PORT) -v /tmp/omnibus:/persist -e EMAIL=owner@example.com -e PASSWORD=topsecret -e TEAM=$(TEAM) -p $(PORT):80 -it paulfitz/grist:omnibus

push:
	docker push paulfitz/grist:omnibus
