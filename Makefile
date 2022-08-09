build:
	docker build -t junk .
	docker tag junk paulfitz/grist:omnibus

run:
	mkdir -p /tmp/zzz
	docker run --rm --name gristy -v /tmp/zzz:/persist -p 9999:80 -it junk
