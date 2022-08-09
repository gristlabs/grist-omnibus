#!/bin/bash

set -ex

FLAGS=("--providers.file.filename=/settings/traefik.yml")
FLAGS+=("--api.dashboard=true --api.insecure=true")
FLAGS+=("--entryPoints.web.address=:80")

FLAGS+=("--certificatesResolvers.letsencrypt.acme.email=paulfitz@getgrist.com")
FLAGS+=("--certificatesResolvers.letsencrypt.acme.storage=/persist/acme.json")
FLAGS+=("--certificatesResolvers.letsencrypt.acme.tlschallenge=true")
FLAGS+=("--entrypoints.websecure.address=:443")
FLAGS+=("--entrypoints.websecure.http.tls=true")

# Add acme + email here for https

traefik ${FLAGS[@]}
