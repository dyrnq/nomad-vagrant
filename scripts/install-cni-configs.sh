#!/usr/bin/env bash


# fun_install(){

# cat >/etc/cni/net.d/mynet.conf<<EOF
# {
#     "cniVersion": "1.0.0",
#     "name": "mynet",
#     "type": "bridge",
#     "bridge": "cni9",
#     "isGateway": true,
#     "ipMasq": true,
#     "ipam": {
#       "type": "host-local",
#       "subnet": "172.19.0.0/24",
#       "routes": [
#         { "dst": "0.0.0.0/0" }
#       ]
#     }
# }
# EOF


# cat >/etc/cni/net.d/10-calico.conflist<<EOF
# {
#     "name": "calico",
#     "cniVersion": "0.3.1",
#     "plugins": [
#       {
#         "type": "calico",
#         "log_level": "info",
#         "log_file_path": "/var/log/calico/cni/cni.log",
#         "datastore_type": "etcdv3",
#         "etcd_endpoints": "http://192.168.33.4:2379",
#         "nodename": "$(hostname)",
#         "mtu": 0,
#         "ipam": {
#             "type": "calico-ipam"
#         }
#       },
#       {
#         "type": "portmap",
#         "snat": true,
#         "capabilities": {"portMappings": true}
#       },
#       {
#         "type": "bandwidth",
#         "capabilities": {"bandwidth": true}
#       }
#     ]
# }
# EOF

# cat >/etc/cni/net.d/10-flannel.conflist<<EOF
# {
#   "name": "flannel",
#   "cniVersion": "0.3.1",
#   "plugins": [
#     {
#       "type": "flannel",
#       "delegate": {
#         "hairpinMode": true,
#         "isDefaultGateway": true
#       }
#     },
#     {
#       "type": "portmap",
#       "capabilities": {
#         "portMappings": true
#       }
#     }
#   ]
# }
# EOF



## same as /etc/cni/net.d/10-testnet.conflist,for nomad found cni config.
# mkdir -p /opt/cni/config/
# /bin/cp -f -v /etc/cni/net.d/10-calico.conflist /opt/cni/config/10-calico.conflist
# /bin/cp -f -v /etc/cni/net.d/10-flannel.conflist /opt/cni/config/10-flannel.conflist
# /bin/cp -r -v /etc/cni/net.d/mynet.conf /opt/cni/config/mynet.conf

# }

fun_post_install(){


mkdir -p /opt/cni/config/

for i in "10-calico.conflist" "10-flannel.conflist"; do
  test -e /etc/cni/net.d/"${i}" && /bin/cp -f -v /etc/cni/net.d/"${i}" /opt/cni/config/"${i}"
done

if systemctl is-active nomad &>/dev/null; then
    echo "reload nomad..."
    systemctl restart nomad
    systemctl status -l nomad --no-pager
fi

}

fun_post_install


