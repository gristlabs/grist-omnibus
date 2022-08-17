############################################################
# Grist omnibus image
# Grist doesn't have a built-in login system, which can be
# a stumbling block for beginners or people just wanting to
# try it out.
# Includes bundled traefik, traefik-forward-auth, and dex.

ARG BASE=gristlabs/grist:latest

# Gather main dependencies.
FROM dexidp/dex:latest as dex
FROM traefik:2.8 as traefik
FROM traefik/whoami as whoami

# recent public traefik-forward-auth image doesn't support arm,
# so build it from scratch.
FROM golang:1.13-alpine as fwd
RUN mkdir -p /go/src/github.com/thomseddon/traefik-forward-auth
WORKDIR /go/src/github.com/thomseddon/traefik-forward-auth
RUN apk add --no-cache git
RUN mkdir -p /go/src/github.com/thomseddon/
RUN cd /go/src/github.com/thomseddon/ && \
  git clone https://github.com/thomseddon/traefik-forward-auth.git && \
  cd traefik-forward-auth && \
  git checkout c4317b7503fb0528d002eb1e5ee43c4a37f055d0
ARG TARGETOS TARGETARCH
RUN echo "Compiling for [$TARGETOS $TARGETARCH] (will be blank if not using BuildKit)"
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH GO111MODULE=on go build -a -installsuffix nocgo \
  -o /traefik-forward-auth github.com/thomseddon/traefik-forward-auth/cmd

# Extend Grist image.
FROM $BASE

# apache2-utils is for htpasswd, used with dex
RUN \
  apt-get update && \
  apt-get install -y --no-install-recommends pwgen apache2-utils curl && \
  apt-get install -y --no-install-recommends ca-certificates tzdata && \
  rm -rf /var/lib/apt/lists/*

# Copy in traefik-forward-auth program.
COPY --from=fwd /traefik-forward-auth /usr/local/bin

# Copy in traeefik program.
COPY --from=traefik /usr/local/bin/traefik /usr/local/bin/traefik

# Copy in all of dex parts, including its funky template-expanding
# entrypoint (rename this to dex-entrypoint).
COPY --from=dex /var/dex /var/dex
COPY --from=dex /etc/dex /etc/dex
COPY --from=dex /usr/local/src/dex/ /usr/local/src/dex/
COPY --from=dex /usr/local/bin/dex /usr/local/bin/dex
COPY --from=dex /srv/dex/web /srv/dex/web
COPY --from=dex /usr/local/bin/gomplate /usr/local/bin/gomplate
COPY --from=dex /usr/local/bin/docker-entrypoint /usr/local/bin/dex-entrypoint

COPY --from=whoami /whoami /usr/local/bin/whoami

COPY dex.yaml /settings/dex.yaml
COPY traefik.yaml /settings/traefik.yaml
COPY run.js /grist/run.js

# Make traefik-forward-auth trust self-signed certificates internally, if user
# chooses to use one.
RUN ln -s /custom/grist.crt /etc/ssl/certs/grist.pem

CMD /grist/run.js

EXPOSE 80 443
