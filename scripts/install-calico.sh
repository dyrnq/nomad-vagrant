#!/usr/bin/env bash
iface="${iface:-eth1}"
ver=${ver:-v3.25.0}

while [ $# -gt 0 ]; do
    case "$1" in
        --iface|-i)
            iface="$2"
            shift
            ;;
        --version|--ver)
            ver="$2"
            shift
            ;;
        --*)
            echo "Illegal option $1"
            ;;
    esac
    shift $(( $# > 0 ? 1 : 0 ))
done

command_exists() {
    command -v "$@" > /dev/null 2>&1
}

fun_install(){
wget --continue https://files.m.daocloud.io/github.com/projectcalico/calico/releases/download/${ver}/calicoctl-linux-amd64
install -m 755 calicoctl-linux-amd64 /usr/local/bin/calicoctl


cat >/usr/local/bin/calicoup.sh<<EOF
mkdir -p /var/log/calico
mkdir -p /var/run/calico
mkdir -p /var/lib/calico

/usr/local/bin/nerdctl run \
--net=host \
--privileged \
--name=calico-node \
--detach \
--restart=always \
-e DATASTORE_TYPE="etcdv3" \
-e ETCD_DISCOVERY_SRV= \
-e ETCD_ENDPOINTS=http://192.168.33.4:2379 \
-e NODENAME=$(hostname) \
-e CALICO_NETWORKING_BACKEND=bird \
-e FELIX_VXLANENABLED=true \
-e IP_AUTODETECTION_METHOD=interface=${iface} \
-e CALICO_MANAGE_CNI=false \
-e CALICO_IPV4POOL_VXLAN=Always \
-e CALICO_IPV4POOL_BLOCK_SIZE=24 \
-e CALICO_IPV4POOL_CIDR=10.244.0.0/16 \
-e CALICO_IPV6POOL_VXLAN=Never \
-e CALICO_IPV4POOL_IPIP=Never \
-e CALICO_IPV6POOL_NAT_OUTGOING=false \
-e FELIX_HEALTHENABLED=true \
-e FELIX_IPV6SUPPORT=false \
-v /var/log/calico:/var/log/calico \
-v /var/run/calico:/var/run/calico \
-v /var/lib/calico:/var/lib/calico \
-v /lib/modules:/lib/modules \
-v /sys/fs:/sys/fs \
-v /run:/run \
docker.io/calico/node:${ver}
EOF

#   DATASTORE_TYPE:                     kubernetes
#   WAIT_FOR_DATASTORE:                 true
#   NODENAME:                            (v1:spec.nodeName)
#   CALICO_NETWORKING_BACKEND:          <set to the key 'calico_backend' of config map 'calico-config'>  Optional: false
#   CLUSTER_TYPE:                       k8s,bgp
#   IP:                                 autodetect
#   CALICO_IPV4POOL_IPIP:               Never
#   CALICO_IPV4POOL_VXLAN:              Always
#   FELIX_IPINIPMTU:                    <set to the key 'veth_mtu' of config map 'calico-config'>  Optional: false
#   FELIX_VXLANMTU:                     <set to the key 'veth_mtu' of config map 'calico-config'>  Optional: false
#   FELIX_WIREGUARDMTU:                 <set to the key 'veth_mtu' of config map 'calico-config'>  Optional: false
#   CALICO_IPV4POOL_CIDR:               10.244.0.0/16
#   IP_AUTODETECTION_METHOD:            interface=eth1
#   CALICO_DISABLE_FILE_LOGGING:        true
#   FELIX_DEFAULTENDPOINTTOHOSTACTION:  ACCEPT
#   FELIX_IPV6SUPPORT:                  false
#   FELIX_HEALTHENABLED:                true


#   calico_backend: bird
#   cni_network_config: |-
#     {
#       "name": "k8s-pod-network",
#       "cniVersion": "0.3.1",
#       "plugins": [
#         {
#           "type": "calico",
#           "log_level": "info",
#           "log_file_path": "/var/log/calico/cni/cni.log",
#           "datastore_type": "kubernetes",
#           "nodename": "__KUBERNETES_NODE_NAME__",
#           "mtu": __CNI_MTU__,
#           "ipam": {
#               "type": "calico-ipam"
#           },
#           "policy": {
#               "type": "k8s"
#           },
#           "kubernetes": {
#               "kubeconfig": "__KUBECONFIG_FILEPATH__"
#           }
#         },
#         {
#           "type": "portmap",
#           "snat": true,
#           "capabilities": {"portMappings": true}
#         },
#         {
#           "type": "bandwidth",
#           "capabilities": {"bandwidth": true}
#         }
#       ]
#     }
#   typha_service_name: none
#   veth_mtu: "0"



cat >/lib/systemd/system/calico-node.service<<EOF
[Unit]
Description=calico-node
After=containerd.service
Requires=containerd.service

[Service]
EnvironmentFile=-/etc/calico/calico.env
# ExecStartPre=-/sbin/modprobe ip6t_rpfilter
# ExecStartPre=-/sbin/modprobe ip6table_nat
# ExecStartPre=-/sbin/modprobe ip6table_raw
# ExecStartPre=-/sbin/modprobe ip6table_mangle
# ExecStartPre=-/sbin/modprobe ip6table_filter
# ExecStartPre=-/sbin/modprobe ip6_tables
ExecStartPre=-/usr/local/bin/nerdctl rm -f calico-node
ExecStart=/usr/bin/bash /usr/local/bin/calicoup.sh

ExecStop=-/usr/local/bin/nerdctl stop calico-node

Restart=on-failure
StartLimitBurst=0
StartLimitInterval=60s

[Install]
WantedBy=multi-user.target
EOF







mkdir -p /etc/calico
mkdir -p /etc/cni/net.d

echo "install calico cni plugins"
nerdctl run \
-it \
--privileged \
--rm \
-v /opt/cni/bin:/host/opt/cni/bin \
-v /etc/cni/net.d:/host/etc/cni/net.d \
docker.io/calico/cni:"${ver}" || true



cat >/etc/calico/calicoctl.cfg<<EOF
apiVersion: projectcalico.org/v3
kind: CalicoAPIConfig
metadata:
spec:
  etcdEndpoints: http://192.168.33.4:2379
  #etcdKeyFile: /etc/etcd/pki/etcd-key.pem
  #etcdCertFile: /etc/etcd/pki/etcd.pem
  #etcdCACertFile: /etc/etcd/pki/ca.pem
EOF




systemctl daemon-reload
if systemctl is-active calico-node &>/dev/null; then
    systemctl restart calico-node
else
    systemctl enable --now calico-node
fi
systemctl status -l calico-node --no-pager

}


fun_install