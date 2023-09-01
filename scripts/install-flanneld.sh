#!/usr/bin/env bash


iface="${iface:-eth1}"
ver=${ver:-v0.22.2}
# https://github.com/flannel-io/flannel/tags

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

curl -fSL -# -O https://files.m.daocloud.io/github.com/flannel-io/flannel/releases/download/${ver}/flannel-${ver}-linux-amd64.tar.gz

tar -xvz -f flannel-${ver}-linux-amd64.tar.gz -C /usr/local/bin


cat >/lib/systemd/system/flanneld.service<<EOF
[Unit]
Description=Flanneld overlay address etcd agent
After=network.target
After=network-online.target
Wants=network-online.target
#After=etcd.service
#Before=docker.service

[Service]
Type=notify
ExecStart=/usr/local/bin/flanneld \
  -etcd-endpoints=http://192.168.33.4:2379 \
  -etcd-prefix=/coreos.com/network \
  -iface=${iface} \
  -ip-masq \
  -v=9
ExecStartPost=/usr/local/bin/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS -d /run/flannel/docker
Restart=always
RestartSec=5
StartLimitInterval=0

[Install]
WantedBy=multi-user.target
#RequiredBy=docker.service
EOF




systemctl daemon-reload
if systemctl is-active flanneld &>/dev/null; then
    systemctl restart flanneld
else
    systemctl enable --now flanneld 
fi
systemctl status -l flanneld --no-pager
}

fun_install