#!/usr/bin/env bash


id=50001
if curl -fSL http://127.0.0.1:9180/apisix/admin/routes/$id -X GET -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' | grep createdIndex; then
    :
else
curl http://127.0.0.1:9180/apisix/admin/routes/$id -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' -X PUT -i -d '
{
  "uri": "/*",
  "name": "nginx",
  "upstream": {
    "timeout": {
      "connect": 6,
      "send": 6,
      "read": 6
    },
    "type": "roundrobin",
    "scheme": "http",
    "discovery_type": "consul",
    "pass_host": "pass",
    "service_name": "nginx",
    "keepalive_pool": {
      "idle_timeout": 60,
      "requests": 1000,
      "size": 320
    }
  }
}'
fi

while true; do
    echo -n "--->$(date)===";
    curl --connect-timeout 1 --max-time 1 http://127.0.0.1:9080;
    echo -n "fetch X-Consul-Index change---->"
    curl -fsSL -i http://127.0.0.1:8500/v1/health/state/any |grep X-Consul-Index
    echo "fetch health from consul";
    curl -fsSL http://127.0.0.1:8500/v1/health/service/nginx?passing=true | jq -r '.[] | "\(.Service.Address):\(.Service.Port)"';
    echo "dump from apisix ******" ;
    curl -fsL http://127.0.0.1:9090/v1/discovery/consul/dump | jq -r '.services."nginx"[] | "\(.host):\(.port)"';
    echo "######################################"
    curl -fsL http://192.168.33.4:9080
    sleep 1s;
done