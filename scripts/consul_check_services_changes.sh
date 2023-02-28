#!/bin/bash
if test "${1:-none}" = "none"
then
  echo "USAGE: $0 Consul_URL"
  echo "       Example: localhost:8500/v1/health/service/MY_SUPER_SERVICE"
  exit 1
fi
url_to_check=$1

headers=$(mktemp)
content=$(mktemp)
index=0
while true;
do
  url="${url_to_check}?wait=5m&index=${index}&pretty=true&stale"
  curl -fs --dump-header "$headers" -o "${content}.new" "${url}" || { "echo Failed to query ${url}"; exit 1; }
  if test $index -ne 0
  then
    diff -u "$content" "$content.new" && echo " diff: No Differences found in service"
  fi
  index=$(grep "X-Consul-Index" "$headers" | sed 's/[^0-9]*\([0-9][0-9]*\)[^0-9]*/\1/g')
  mv "$content.new" "$content"
  printf "X-Consul-Index: $index at $(date) \b"
done