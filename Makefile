build:
	docker build -t junk .
	docker tag junk paulfitz/grist:omnibus

run:
	mkdir -p /tmp/zzz
	docker run --rm --name gristy -e APP_HOME_URL=http://localhost:9999 -v /tmp/zzz:/persist -p 9999:80 -it junk

tag:
	make build
	docker tag junk paulfitz/grist:omnibus
	docker push paulfitz/grist:omnibus
