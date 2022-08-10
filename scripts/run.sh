#!/usr/bin/env bash

set -e

mkdir -p /persist/auth
# chmod a+rwx /persist/auth

# won't be needed shortly
export NEW_DEAL=true

export GRIST_SANDBOX_FLAVOR=gvisor

export GRIST_HIDE_UI_ELEMENTS=helpCenter,billing,templates,multiSite,multiAccounts

export URL="${URL:-$APP_HOME_URL}"

if [[ "$URL" = "" ]]; then
  echo "Please define URL so I know how users will access me."
  exit 1
fi

if [[ "$EMAIL" = "" ]]; then
  echo "Please provide an EMAIL, needed for certificates and initial login."
  exit 1
fi

if [[ ! "$TEAM" = "" ]]; then
  export GRIST_SINGLE_ORG="$TEAM"
  export GRIST_DEFAULT_EMAIL="$EMAIL"
  export GRIST_ORG_IN_PATH=false  # how to stop the /o/...?
fi

export APP_HOME_URL="$URL"

export APP_HOST=$(node -e "console.log(new URL(process.env.APP_HOME_URL).hostname)")

export EXT_PORT=$(node -e "console.log(new URL(process.env.APP_HOME_URL).port)")
export EXT_PORT=${EXT_PORT:-9999}
echo "EXT_PORT $EXT_PORT"

# traefik-forward-auth will try to talk directly to dex, so it is important
# that URL works internally. But if URL contains localhost, it really won't.
# We can finess that by tying DEX_PORT to EXT_PORT in that case. As long as
# it isn't 80 or 443, since traefik is listening there, but that's ok too,
# since traefik will just forward things along.

export DEX_PORT=9999
if [[ "$APP_HOST" = "localhost" ]]; then
  export DEX_PORT=$EXT_PORT
fi
if [[ "$DEX_PORT" = "80" || "$DEX_PORT" = "443" ]]; then
  export DEX_PORT=9999
fi

first=${DEX_PORT:0:1}
echo "FIRST $first"

alt="1"
if [[ "$first" = "$alt" ]]; then
  alt="2"
fi


# Keep other ports out of way of dex port
export GRIST_PORT=${alt}7100
export TFA_PORT=${alt}7101
export WHOAMI_PORT=${alt}7102

export APP_HOST=${APP_HOST:-localhost}
echo "APP_HOST $APP_HOST"

#ALT_PORT=8485

#export GRIST_PORT=8484
#if [[ "$GRIST_PORT" = "$EXT_PORT" ]]; then
#  export GRIST_PORT=$ALT_PORT
#fi

#exit 1

export GRIST_FORWARD_AUTH_HEADER="X-Forwarded-User"
export GRIST_FORWARD_AUTH_LOGOUT_PATH="_oauth/logout"
export GRIST_FORCE_LOGIN="true"

# Start Grist server.
PORT=$GRIST_PORT /grist/sandbox/run.sh &

export DEFAULT_PROVIDER=oidc
export PROVIDERS_OIDC_CLIENT_ID=$(/scripts/invent.sh PROVIDERS_OIDC_CLIENT_ID)
export PROVIDERS_OIDC_CLIENT_SECRET=$(/scripts/invent.sh PROVIDERS_OIDC_CLIENT_SECRET)
export PROVIDERS_OIDC_ISSUER_URL="$APP_HOME_URL/dex"
export SECRET=$(/scripts/invent.sh TFA_SECRET)
export LOGOUT_REDIRECT="$APP_HOME_URL/signed-out"

# Start Traefik reverse proxy.
(
  /scripts/run_traefik.sh
) &

# Start dex auth service.
cp /settings/dex.yaml /persist/dex-full.yaml
node /scripts/add-dex-users.js | tee /persist/dex-users.yaml
cat /persist/dex-users.yaml >> /persist/dex-full.yaml
if [[ -e /custom/dex.yaml ]]; then
  echo "Using /custom/dex.yaml"
  cat /custom/dex.yaml >> /persist/dex-full.yaml
else
  echo "No custom dex.yaml"
fi

dex-entrypoint dex serve /persist/dex-full.yaml &

# Start forward auth service. Delay a little bit since it depends on
# other parts bein up and running.
(
  while true; do
    curl $PROVIDERS_OIDC_ISSUER_URL && break || {
      echo "Waiting for $PROVIDERS_OIDC_ISSUER_URL to look sane"
      sleep 3
    }
  done
  echo "I now hope $PROVIDERS_OIDC_ISSUER_URL is sane, starting traefik-forward-auth"
  traefik-forward-auth --port=$TFA_PORT
) &

WHOAMI_PORT_NUMBER=$WHOAMI_PORT whoami &

# Sit back and enjoy the show.
wait
