#!/usr/bin/env bash

set -e

mkdir -p /persist/auth
# chmod a+rwx /persist/auth

export APP_HOME_URL="${APP_HOME_URL:-http://localhost:9999}"

export EXT_PORT=$(node -e "console.log(new URL(process.env.APP_HOME_URL).port)")
export EXT_PORT=${EXT_PORT:-9999}
echo "EXT_PORT $EXT_PORT"

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
/grist/sandbox/run.sh &

# Start Traefik reverse proxy.
(
  cd /persist
  /scripts/run_traefik.sh
) &

source /settings/fwd.sh

# Start dex auth service.
dex-entrypoint dex serve /settings/dex.yaml &

# Start forward auth service. Delay a little bit since it depends on
# other parts bein up and running.
(
  sleep 3
  traefik-forward-auth
) &

WHOAMI_PORT_NUMBER=2222 whoami &

# Sit back and enjoy the show.
wait
