# nomad vagrant

## introduce

This is a project that attempts to create a working nomad cluster with nomad + consul + containerd + cni + flanneld(or calico) + etcd + nomad-driver-containerd, using Vagrant.

tks [nekione`s nekione/calico-nomad](https://github.com/nekione/calico-nomad).

<!-- TOC -->

- [nomad vagrant](#nomad-vagrant)
  - [introduce](#introduce)
  - [start vms](#start-vms)
  - [cni options](#cni-options)
    - [flannel](#flannel)
      - [install flanneld](#install-flanneld)
      - [init flanneld network config](#init-flanneld-network-config)
      - [test flannel network](#test-flannel-network)
      - [run nomad job with cni flannel](#run-nomad-job-with-cni-flannel)
    - [calico](#calico)
      - [install calico-node](#install-calico-node)
      - [reinit calico default-ipv4-ippool](#reinit-calico-default-ipv4-ippool)
      - [test calico network](#test-calico-network)
      - [run nomad job with cni calico](#run-nomad-job-with-cni-calico)
  - [apache apisix with consul](#apache-apisix-with-consul)
    - [basic knowledge](#basic-knowledge)
    - [install apisix and apisix-dashboard](#install-apisix-and-apisix-dashboard)
    - [service discovery var consul dns](#service-discovery-var-consul-dns)
    - [put route with apisix admin api](#put-route-with-apisix-admin-api)
    - [test watch](#test-watch)
  - [conclusion](#conclusion)
  - [clickhouse](#clickhouse)
  - [ref](#ref)

<!-- /TOC -->

## start vms

```bash
vagrant up vm4 vm5 vm6 vm7
```

| vm   | ip            | install                                                    |
|------|---------------|------------------------------------------------------------|
| vm4  | 192.168.33.4  | containerd,consul(server+client),nomad(server+client),etcd |
| vm5  | 192.168.33.5  | containerd,consul(server+client),nomad(server+client)      |
| vm6  | 192.168.33.6  | containerd,consul(server+client),nomad(server+client)      |
| vm7  | 192.168.33.7  | containerd,consul(client),nomad(client)                    |
| vm14 | 192.168.33.14 | containerd,zookeeper,kafka                                 |
| vm15 | 192.168.33.15 | containerd,clickhouse                                      |

take notice of etcd not HA, just for test and demonstration.

## cni options

### flannel

#### install flanneld

```bash
bash /vagrant/scripts/install-flanneld.sh
bash /vagrant/scripts/install-cni-configs.sh
```

#### init flanneld network config

```bash
etcdctl put /coreos.com/network/config '{ "Network": "10.5.0.0/16", "Backend": {"Type": "vxlan"} }'
```

```bash
etcdctl get --from-key /coreos.com -w simple

/coreos.com/network/config
{ "Network": "10.5.0.0/16", "Backend": {"Type": "vxlan"} }
/coreos.com/network/subnets/10.5.37.0-24
{"PublicIP":"192.168.33.6","PublicIPv6":null,"BackendType":"vxlan","BackendData":{"VNI":1,"VtepMAC":"02:52:fb:99:b1:f2"}}
/coreos.com/network/subnets/10.5.42.0-24
{"PublicIP":"192.168.33.4","PublicIPv6":null,"BackendType":"vxlan","BackendData":{"VNI":1,"VtepMAC":"de:52:46:32:23:c7"}}
/coreos.com/network/subnets/10.5.53.0-24
{"PublicIP":"192.168.33.5","PublicIPv6":null,"BackendType":"vxlan","BackendData":{"VNI":1,"VtepMAC":"c6:c0:13:b9:16:35"}}
/coreos.com/network/subnets/10.5.93.0-24
{"PublicIP":"192.168.33.7","PublicIPv6":null,"BackendType":"vxlan","BackendData":{"VNI":1,"VtepMAC":"4e:99:34:be:6d:4d"}}
```

#### test flannel network

```bash
nerdctl run --net cbr0 -it --rm dyrnq/nettools bash -c "ip a show dev eth0 && sleep 2s && ping -c 5 192.168.33.1"
```

#### run nomad job with cni flannel

first use `nomad run` deploy job, just like `kubectl apply -f foo.yaml`.

```bash
nomad stop -purge netshoot-2 || true
nomad run -detach /vagrant/nomad-jobs/example-job-cni-flannel.hcl

nomad job status netshoot-2
```

### calico

#### install calico-node

```bash
bash /vagrant/scripts/install-calico.sh
bash /vagrant/scripts/install-cni-configs.sh
```

#### reinit calico default-ipv4-ippool

```bash
calicoctl delete ippools default-ipv4-ippool
calicoctl create -f -<<EOF
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: default-ipv4-ippool
spec:
  allowedUses:
  - Workload
  - Tunnel
  blockSize: 24
  cidr: 10.244.0.0/16
  ipipMode: Never
  natOutgoing: true
  nodeSelector: all()
  vxlanMode: Always
EOF
calicoctl get ippools default-ipv4-ippool -o json

calicoctl ipam check

calicoctl ipam show --show-blocks

calicoctl get nodes -o wide

calicoctl node status
```

#### test calico network

```bash
nerdctl run --net testnet -it --rm dyrnq/nettools bash -c "ip a show dev eth0 && sleep 2s && ping -c 5 192.168.33.1"
```

#### run nomad job with cni calico

first use `nomad run` deploy job, just like `kubectl apply -f foo.yaml`.

```bash
nomad run -detach /vagrant/nomad-jobs/example-job-cni-calico.hcl

nomad job status netshoot-1
```

then, waiting job running use `nerdctl ps` found running containers.

```bash
nerdctl -n nomad ps -a
```

remove job

```bash
nomad job stop -purge netshoot-1
```

quick rerun

```bash
nomad job stop -purge netshoot-1 && nomad run -detach /vagrant/nomad-jobs/example-job-cni-calico.hcl

```

## apache apisix with consul

### basic knowledge

>How to use Consul as Registration Center in Apache APISIX?

[xref](https://gist.github.com/hzbd/e36245256dfaa96da96f3ae1d83ef790)

>Integration service discovery registry

[xref](https://apisix.apache.org/docs/apisix/discovery/consul/)

### install apisix and apisix-dashboard

```bash
bash /vagrant/scripts/install-apisix.sh
```

### service discovery var consul dns

```bash
dig @127.0.0.1 -p 8600 nomad.service.dc1.consul. ANY
dig @127.0.0.1 -p 8600 nomad-client.service.dc1.consul. ANY

dig @127.0.0.1 -p 8600 netshoot-2-netshoot-group.service.dc1.consul. ANY
```

### put route with apisix admin api

> option disconvery var DNS

```bash

curl http://127.0.0.1:9180/apisix/admin/routes/1 -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' -X PUT -i -d '
{
  "uri": "/",
  "name": "consul-netshoot-2-netshoot-group",
  "upstream": {
    "timeout": {
      "connect": 6,
      "send": 6,
      "read": 6
    },
    "type": "roundrobin",
    "scheme": "http",
    "discovery_type": "dns",
    "pass_host": "pass",
    "service_name": "netshoot-2-netshoot-group.service.dc1.consul:8080",
    "keepalive_pool": {
      "idle_timeout": 60,
      "requests": 1000,
      "size": 320
    }
  }
}'

```

> option disconvery var Consul

```bash
curl http://127.0.0.1:9180/apisix/admin/routes/1 -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1' -X PUT -i -d '
{
  "uri": "/",
  "name": "consul-netshoot-2-netshoot-group",
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
    "service_name": "netshoot-2-netshoot-group",
    "keepalive_pool": {
      "idle_timeout": 60,
      "requests": 1000,
      "size": 320
    }
  }
}'
```

```bash
curl -fsSL http://127.0.0.1:8500/v1/catalog/service/netshoot-2-netshoot-group | jq -r '.[] | "\(.ServiceAddress):\(.ServicePort)"'
```

```bash
curl -fsL http://127.0.0.1:9090/v1/discovery/consul/dump | jq -r '.services."netshoot-2-netshoot-group"[] | "\(.host):\(.port)"'
```

### test watch

```bash
while true ; do curl http://127.0.0.1:9080; sleep 2s; echo "------------>";  done
```

scale job

```bash
# first increase
nomad job scale -detach netshoot-2 20

# then decrease
nomad job scale -detach netshoot-2 1
```

## conclusion

Flanneld and calico are all work fine with nomad, nomad can use cni and nomad-driver-containerd create containers successfully, but calico subnet can not connect with each other.

## clickhouse

```bash
CREATE DATABASE IF NOT EXISTS LOG

CREATE TABLE LOG.log_queue
(
    `log` String
)
ENGINE = Kafka
SETTINGS 
  kafka_broker_list = '192.168.33.14:9092',
  kafka_topic_list = 'log_demo',
  kafka_group_name = 'ck-log',
  kafka_format = 'JSONAsString';



CREATE TABLE LOG.rawlog
(
    `message` String CODEC(ZSTD(1)),
    `hostname` String,
    `logfile_path` String,
    `log_time` DateTime DEFAULT now(),
     INDEX message message TYPE tokenbf_v1(30720, 2, 0) GRANULARITY 1
)
ENGINE = MergeTree
PARTITION BY (toDate(log_time))
ORDER BY (log_time)
TTL log_time + toIntervalDay(30)
SETTINGS index_granularity = 8192;

CREATE MATERIALIZED VIEW LOG.mv_rawlog TO LOG.rawlog
(
    `message` String,
    `hostname` String,
    `logfile_path` String,
    `log_time` DateTime
) AS
SELECT
    JSONExtractString(log, 'message') AS message,
    JSONExtractString(JSONExtractString(log, 'host'), 'name') AS hostname,
    JSONExtractString(JSONExtractString(JSONExtractString(log, 'log'), 'file'), 'path') AS logfile_path,
    now() AS log_time
FROM LOG.log_queue;
```

## ref

- <https://github.com/hashicorp/nomad/blob/main/demo/vagrant/Vagrantfile>
- <https://github.com/hashicorp/nomad/blob/main/demo/digitalocean/packer/nomad/default.hcl>
- <https://github.com/hashicorp/consul/blob/main/agent/config/testdata/full-config.json>
- <https://github.com/hashicorp/consul/blob/main/agent/config/testdata/full-config.hcl>
- <https://github.com/nekione/calico-nomad>
- <https://docs.tigera.io/calico/3.25/getting-started/bare-metal/installation/container>
- <https://hashicorp.github.io/nomad-cheatsheet/>
- <https://github.com/projectcalico/calico/blob/v3.25.0/calico/reference/node/configuration.md>
