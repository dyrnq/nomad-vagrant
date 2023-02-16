#!/usr/bin/env bash


iface="${iface:-enp0s8}"
ver=${ver:-v1.10.1}

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

ip4=$(/sbin/ip -o -4 addr list "${iface}" | awk '{print $4}' |cut -d/ -f1 | head -n1);


command_exists() {
    command -v "$@" > /dev/null 2>&1
}



fun_install(){
local ver_nov
ver_nov="${ver:1}"
wget --continue https://files.m.daocloud.io/github.com/coredns/coredns/releases/download/${ver}/coredns_${ver_nov}_linux_amd64.tgz
tar -xvz -f coredns_"${ver_nov}"_linux_amd64.tgz -C /usr/local/bin/
chmod +x /usr/local/bin/coredns

mkdir -p /etc/coredns



cat >/etc/coredns/Corefile<<EOF
# dev.local {
#     etcd {
#         path /skydns
#         endpoint https://192.168.33.11:2379 https://192.168.33.12:2379 https://193.168.33.13:2379
#         tls /etc/etcd/etcd-healthcheck-client.pem /etc/etcd/etcd-healthcheck-client-key.pem /etc/etcd/etcd-ca.pem
#     }
#     prometheus
#     cache
#     loadbalance
#     log    
# }


.:53 {
    bind dummy0    
    errors
    health {
        lameduck 5s
    }
    ready
    prometheus :9153

    forward . 127.0.0.1:8600 10.0.2.3 8.8.8.8 {
        policy sequential
        max_concurrent 1000
    }
    hosts /etc/add_hosts {
        fallthrough
    }
    cache 30
    loop
    reload
    loadbalance
    log
}
EOF


cat >/lib/systemd/system/coredns.service<<EOF
[Unit]
Description=coredns
Documentation=https://github.com/coredns/coredns
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/coredns -conf /etc/coredns/Corefile
Restart=on-failure
RestartSec=1s
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF


modprobe -v dummy
#ip link del dummy0 type dummy

if ip link show dummy0 type dummy; then
    :
else
    ip link add dummy0 type dummy
    ip link set dev dummy0 mtu 1500
    ip link set dev dummy0 up
    ip link set dummy0 address 00:00:00:11:11:11
    ip addr add 10.10.10.2/24 dev dummy0
fi


# ipvsadm --add-service --tcp-service 10.10.10.2:53 --scheduler rr || true
# ipvsadm --add-server --tcp-service 10.10.10.2:53 --real-server 127.0.0.1:5353 --masquerading --weight 1 || true
# ipvsadm --delete-service --tcp-service 10.10.10.2:53 || true




## /etc/resolv.conf on ubuntu
if systemctl is-active systemd-resolved; then

    mkdir -p /etc/systemd/resolved.conf.d/
cat >/etc/systemd/resolved.conf.d/99-dns.conf << EOF
[Resolve]
DNS=10.10.10.2 8.8.8.8
EOF
    ln -s -f /run/systemd/resolve/resolv.conf /etc/resolv.conf
    systemctl daemon-reload && systemctl restart systemd-resolved.service && systemctl status -l systemd-resolved.service --no-pager && cat /etc/resolv.conf
fi



systemctl daemon-reload
if systemctl is-active coredns &>/dev/null; then
    systemctl restart coredns
else
    systemctl enable --now coredns
fi
systemctl status -l coredns --no-pager

}

fun_install




