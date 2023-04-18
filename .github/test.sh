#!/bin/bash

set -ex
# Does a very simple smoke test to make sure Grist API is available
# In .github directory just to avoid adding more files/directories
# in root :-)

IMAGE=gristlabs/grist-omnibus
TEAM=cool-beans
PORT=9998

mkdir -p /tmp/omnibus-test
docker run --rm --name grist \
       -e URL=http://localhost:$PORT \
       -v /tmp/omnibus-test:/persist \
       -e EMAIL=owner@example.com \
       -e PASSWORD=topsecret \
       -e TEAM=$TEAM \
       -p $PORT:80 \
       -d $IMAGE

function finish {
  docker logs grist || echo no logs
  docker kill grist > /dev/null
}
trap finish EXIT

for ct in $(seq 1 20); do
  echo "Check $ct"
  check="$(curl http://localhost:$PORT/api/orgs || echo fail)"
  if [[ "$check" = "[]" ]]; then
    echo Grist is responsive
    exit 0
  fi
  sleep 1
done

echo "Grist did not respond"
exit 1
