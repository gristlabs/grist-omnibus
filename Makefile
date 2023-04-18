PORT = 8484
TEAM = cool-beans

# Possible bases: gristlabs/grist, or gristlabs/grist-ee
BASE = gristlabs/grist
IMAGE = $(BASE)-omnibus

build:
	docker build --build-arg BASE=$(BASE) -t $(IMAGE) .

run:
	mkdir -p /tmp/omnibus
	docker run --rm --name grist \
          -e URL=http://localhost:$(PORT) \
          -v /tmp/omnibus:/persist \
          -e EMAIL=owner@example.com \
          -e PASSWORD=topsecret \
          -e TEAM=$(TEAM) \
          -p $(PORT):80 \
          -it $(IMAGE)

push:
	docker push $(IMAGE)

buildwitharch:
	DOCKER_BUILDKIT=1 docker buildx build \
          --platform linux/amd64,linux/arm64 \
          --build-arg BASE=$(BASE) \
          -t $(IMAGE) .
	DOCKER_BUILDKIT=1 docker buildx build \
          --build-arg BASE=$(BASE) \
          -t $(IMAGE) --load .

pushwitharch:
	DOCKER_BUILDKIT=1 docker buildx build \
          --platform linux/amd64,linux/arm64 \
          --build-arg BASE=$(BASE) \
          -t $(IMAGE) --push .

test:
	./.github/test.sh

makecert:
	@echo "Put grist.example.com in your /etc/hosts as 127.0.0.1, and make a self-signed cert for it"
	openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -sha256 -days 365 -nodes

runwithcert:
	mkdir -p /tmp/omnibus
	docker run --rm --name grist \
          -e URL=https://grist.example.com:$(PORT) \
	  -e HTTPS=manual \
	  -v $(PWD)/key.pem:/custom/grist.key \
	  -v $(PWD)/cert.pem:/custom/grist.crt \
          -v /tmp/omnibus:/persist \
          -e EMAIL=owner@example.com \
          -e PASSWORD=topsecret \
          -e TEAM=$(TEAM) \
          -p $(PORT):443 \
	  --add-host grist.example.com:$(shell docker network inspect --format='{{range .IPAM.Config}}{{.Gateway}}{{end}}' bridge) \
          -it $(IMAGE)
