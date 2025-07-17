############################################################
# Grist omnibus image
# Grist doesn't have a built-in login system, which can be
# a stumbling block for beginners or people just wanting to
# try it out.
# Includes bundled traefik and dex.

ARG BASE=gristlabs/grist:latest

# Gather main dependencies.
FROM dexidp/dex:v2.33.1 AS dex
FROM traefik:2.8 AS traefik
FROM traefik/whoami AS whoami

# Extend Grist image.
FROM $BASE AS merge

# Enable sandboxing by default. It is generally important when sharing with
# others. You may override it, e.g. "unsandboxed" uses no sandboxing but is
# only OK if you trust all users fully.
ENV GRIST_SANDBOX_FLAVOR=gvisor

# apache2-utils is for htpasswd, used with dex
RUN \
  apt-get update && \
  apt-get install -y --no-install-recommends pwgen apache2-utils curl && \
  apt-get install -y --no-install-recommends ca-certificates tzdata && \
  rm -rf /var/lib/apt/lists/*

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

# Squashing this way loses environment variables set in base image
# so we need to revert it for now.
# # One last layer, to squash everything.
# FROM scratch
# COPY --from=merge / /

CMD ["/grist/run.js"]

EXPOSE 80 443
