#!/usr/bin/env bash


for i in 1 2 4; do
    nerdctl rm -f nginx-$i 2>/dev/null || true
    mkdir -p /tmp/nginx-$i && echo "nginx-$i" > /tmp/nginx-$i/index.html
    nerdctl run -d -p "${i}"8080:80 --name nginx-$i -v /tmp/nginx-$i:/usr/share/nginx/html nginx:latest
done

echo "deregister all nginx instance"
for i in 1 2 3 4; do
    curl -fsS http://127.0.0.1:8500/v1/agent/service/deregister/nginx-"$i" -X PUT || true
done

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
        "interval": "1s",
        "timeout": "6ms"
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
        "interval": "1s",
        "timeout": "6ms"
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
        "interval": "1s",
        "timeout": "6ms"
    }]
}
'

echo "register nginx instance without check"
curl http://127.0.0.1:8500/v1/agent/service/register -X PUT -d '
{
    "name": "nginx",
    "id": "nginx-4",
    "address": "192.168.33.4",
    "port": 48080,
    "tags": ["dev"]
}
'


(
echo "fetch endpoint from catalog API"
curl -fsSL http://127.0.0.1:8500/v1/catalog/service/nginx | jq -r '.[] | "\(.ServiceAddress):\(.ServicePort)"'
echo "fetch endpoint from health API without health filter"
curl -fsSL http://127.0.0.1:8500/v1/health/service/nginx | jq -r '.[] | "\(.Service.Address):\(.Service.Port)"'
echo "fetch endpoint from health API with health filter"
curl -fsSL http://127.0.0.1:8500/v1/health/service/nginx?passing=true | jq -r '.[] | "\(.Service.Address):\(.Service.Port)"'
# https://developer.hashicorp.com/consul/api-docs/health#passing
)
dig @127.0.0.1 -p 8600 -t srv nginx.service.dc1.consul. +short


# fetch endpoint from catalog API
# 192.168.33.4:18080
# 192.168.33.4:28080
# 192.168.33.4:38080
# 192.168.33.4:48080
# fetch endpoint from health API without health filter
# 192.168.33.4:18080
# 192.168.33.4:28080
# 192.168.33.4:38080
# 192.168.33.4:48080
# fetch endpoint from health API with health filter
# 192.168.33.4:18080
# 192.168.33.4:28080
# 192.168.33.4:48080

# bash ./consul_check_services_changes.sh http://127.0.0.1:8500/v1/health/state/any