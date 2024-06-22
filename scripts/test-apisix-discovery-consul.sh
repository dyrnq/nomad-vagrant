#!/usr/bin/env bash


for i in 4 5 6; do

curl http://127.0.0.1:8500/v1/agent/service/register -X PUT --data @<(cat <<EOF
{
    "name": "httpbin",
    "id": "httpbin-${i}",
    "address": "192.168.33.${i}",
    "port": 9992,
    "tags": ["dev"],
    "checks": [{
        "http": "http://192.168.33.${i}:9992",
        "interval": "1s",
        "timeout": "100ms"
    }]
}
EOF
)
done

id=50001

curl http://127.0.0.1:9180/apisix/admin/routes/$id -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' -X PUT -i --data @<(cat <<'EOF'
{
  "uri": "/*",
  "name": "httpbin-by-consul",
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
    "service_name": "httpbin",
    "keepalive_pool": {
      "idle_timeout": 60,
      "requests": 1000,
      "size": 320
    }
  }
}
EOF
)


while true; do
    echo -n "--->$(date)===";
    curl --connect-timeout 1 --max-time 1 -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:9080;
    echo -n "fetch X-Consul-Index change---->"
    curl -fsSL -i http://127.0.0.1:8500/v1/health/state/any |grep X-Consul-Index
    echo "fetch health from consul";
    curl -fsSL http://127.0.0.1:8500/v1/health/service/httpbin?passing=true | jq -r '.[] | "\(.Service.Address):\(.Service.Port)"';
    echo "dump from apisix ******" ;
    curl -fsL http://127.0.0.1:9090/v1/discovery/consul/dump | jq -r '.services."httpbin"[] | "\(.host):\(.port)"';
    echo "######################################"
    curl -fsL http://192.168.33.4:9080/anything
    sleep 1s;
done