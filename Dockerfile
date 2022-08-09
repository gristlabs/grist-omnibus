############################################################
# Grist omnibus image
# Grist doesn't have a built-in login system, which can be
# a stumbling block for beginners or people just wanting to
# try it out.
# Includes bundled traefik, traefik-forward-auth, and dex.

# Gather main dependencies.
FROM thomseddon/traefik-forward-auth:2 as fwd
# FROM dexidp/dex:v2.33.0-distroless as dex
FROM dexidp/dex:latest as dex
FROM traefik:2.8 as traefik
FROM traefik/whoami as whoami

# Extend Grist image.
FROM gristlabs/grist

RUN \
  apt-get update && \
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

COPY settings /settings
COPY scripts /scripts

RUN mkdir -p /persist/auth

CMD /scripts/run.sh
