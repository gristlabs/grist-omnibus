PORT = 8484
TEAM = cool-beans
IMAGE = paulfitz/grist:omnibus

build:
	docker build -t $(IMAGE) .

buildwitharch:
	DOCKER_BUILDKIT=1 docker buildx build \
          --platform linux/amd64,linux/arm64 \
          -t $(IMAGE) .
	DOCKER_BUILDKIT=1 docker buildx build \
          -t $(IMAGE) --load .

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

pushwitharch:
	DOCKER_BUILDKIT=1 docker buildx build \
          --platform linux/amd64,linux/arm64 \
          -t $(IMAGE) --push .
