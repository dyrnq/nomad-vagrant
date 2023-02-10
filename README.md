# nomad vagrant

## introduce

This is a project that attempts to create a working nomad cluster with nomad + consul + containerd + cni + flanneld + calico + etcd + nomad-driver-containerd, using Vagrant.

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
  - [conclusion](#conclusion)
  - [ref](#ref)

<!-- /TOC -->

## start vms

```bash
vagrant up vm4 vm5 vm6 vm7
```

| vm  | ip           | install                                                    |
|-----|--------------|------------------------------------------------------------|
| vm4 | 192.168.33.4 | containerd,consul(server+client),nomad(server+client),etcd |
| vm5 | 192.168.33.5 | containerd,consul(server+client),nomad(server+client)      |
| vm6 | 192.168.33.6 | containerd,consul(server+client),nomad(server+client)      |
| vm7 | 192.168.33.7 | containerd,consul(client),nomad(client)                    |

take notice of etcd not HA, just for test and demonstration.

## cni options

### flannel

#### install flanneld

```bash
bash /vagrant/script/install-flannel.sh
bash /vagrant/script/install-cni-configs.sh
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
nomad run -detach /vagrant/nomad-jobs/example-job-cni-flannel.hcl

nomad job status netshoot-2
```

### calico

#### install calico-node

```bash
bash /vagrant/script/install-calico.sh
bash /vagrant/script/install-cni-configs.sh
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

```bash
nomad job stop -purge netshoot-1 && nomad run -detach /vagrant/nomad-jobs/example-job-cni.hcl

```

## conclusion

flanneld and calico are all work fine with nomad,but calico-node subnet can not connect with each other.

## ref

- <https://github.com/hashicorp/nomad/blob/main/demo/vagrant/Vagrantfile>
- <https://github.com/hashicorp/nomad/blob/main/demo/digitalocean/packer/nomad/default.hcl>
- <https://github.com/hashicorp/consul/blob/main/agent/config/testdata/full-config.json>
- <https://github.com/hashicorp/consul/blob/main/agent/config/testdata/full-config.hcl>
- <https://github.com/nekione/calico-nomad>
- <https://docs.tigera.io/calico/3.25/getting-started/bare-metal/installation/container>
- <https://hashicorp.github.io/nomad-cheatsheet/>
- <https://github.com/projectcalico/calico/blob/v3.25.0/calico/reference/node/configuration.md>
