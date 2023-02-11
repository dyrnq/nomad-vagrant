#!/usr/bin/env bash

nerdctl rm -f nginx-1 2>/dev/null || true
nerdctl rm -f nginx-2 2>/dev/null || true


mkdir -p /tmp/nginx-1 && echo "nginx-1" > /tmp/nginx-1/index.html
mkdir -p /tmp/nginx-2 && echo "nginx-2" > /tmp/nginx-2/index.html

nerdctl run -d -p 18080:80 --name nginx-1 -v /tmp/nginx-1:/usr/share/nginx/html nginx:latest
nerdctl run -d -p 28080:80 --name nginx-2 -v /tmp/nginx-2:/usr/share/nginx/html nginx:latest


echo "register an health nginx instance"
curl http://127.0.0.1:8500/v1/agent/service/register -X PUT -d '
{
    "name": "nginx",
    "id": "nginx-1",
    "address": "192.168.33.4",
    "port": 18080,
    "tags": ["dev"],
    "checks": [{
        "http": "http://192.168.33.4:18080",
        "interval": "1s"
    }]
}
'
echo "register another health nginx instance"
curl http://127.0.0.1:8500/v1/agent/service/register -X PUT -d '
{
    "name": "nginx",
    "id": "nginx-2",
    "address": "192.168.33.4",
    "port": 28080,
    "tags": ["dev"],
    "checks": [{
        "http": "http://192.168.33.4:28080",
        "interval": "1s"
    }]
}
'
echo "register an unhealth nginx instance"

curl http://127.0.0.1:8500/v1/agent/service/register -X PUT -d '
{
    "name": "nginx",
    "id": "nginx-3",
    "address": "192.168.33.4",
    "port": 38080,
    "tags": ["dev"],
    "checks": [{
        "http": "http://192.168.33.4:38080",
        "interval": "1s"
    }]
}
'

(
echo "fetch endpoint from catalog API"
curl -fsSL http://127.0.0.1:8500/v1/catalog/service/nginx | jq -r ".[].ServiceAddress"
echo "fetch endpoint from health API without health filter"
curl -fsSL http://127.0.0.1:8500/v1/health/service/nginx | jq -r '.[].Service.Address'
echo "fetch endpoint from health API with health filter"
curl -fsSL http://127.0.0.1:8500/v1/health/service/nginx?passing=true | jq -r '.[].Service.Address'
# https://developer.hashicorp.com/consul/api-docs/health#passing
)