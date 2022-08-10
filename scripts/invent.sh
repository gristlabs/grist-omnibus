#!/bin/bash

set -e

key="$1"
shift

mkdir -p /persist/params

if [[ ! -e /persist/params/$key ]]; then
  pwgen -s 20 > /persist/params/$key
fi
  
cat /persist/params/$key
