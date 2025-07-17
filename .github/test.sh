#!/bin/bash

set -ex
# Does a very simple smoke test to make sure Grist API is available
# In .github directory just to avoid adding more files/directories
# in root :-)

IMAGE=gristlabs/grist-omnibus
TEAM=cool-beans
PORT=9998

function finish {
  HTTPS=$1
  docker logs grist$HTTPS || echo no logs
  docker kill grist$HTTPS > /dev/null
}
trap finish EXIT


function run_test() {
  HTTPS=$1
  docker run --rm --name grist$HTTPS \
         -e HTTPS=$HTTPS \
         -e URL=http://localhost:$PORT \
         -v /tmp/omnibus-test:/persist \
         -e EMAIL=owner@example.com \
         -e PASSWORD=topsecret \
         -e TEAM=$TEAM \
         -p $PORT:80 \
         -d $IMAGE

  for ct in $(seq 1 20); do
    echo "Check $ct"
    check="$(curl http://localhost:$PORT/api/orgs || echo fail)"
    if [[ "$check" = "[]" ]]; then
      echo Grist is responsive with "HTTPS=$HTTPS"
      return
    fi
    sleep 1
  done

  echo "Grist did not respond"
  exit 1
}

mkdir -p /tmp/omnibus-test

run_test external
finish external

run_test
