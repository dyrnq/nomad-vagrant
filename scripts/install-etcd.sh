#!/usr/bin/env bash


iface="${iface:-enp0s8}"
ver=${ver:-v3.5.6}

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
fun_install() {

local ETCD_VER
ETCD_VER="${ver}"
DOWNLOAD_URL="https://files.m.daocloud.io/github.com/etcd-io/etcd/releases/download"
rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
rm -rf /tmp/etcd-download-test && mkdir -p /tmp/etcd-download-test

curl -# -L ${DOWNLOAD_URL}/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz
tar xzvf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz -C /tmp/etcd-download-test --strip-components=1
rm -f /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz

/tmp/etcd-download-test/etcd --version
/tmp/etcd-download-test/etcdctl version
/tmp/etcd-download-test/etcdutl version

cp --force /tmp/etcd-download-test/etcd* /usr/local/bin
chmod +x /usr/local/bin/etcd*

ls -l /usr/local/bin


mkdir -p /var/lib/etcd
mkdir -p /etc/etcd/
mkdir -p /etc/etcd/pki/



cat > /etc/etcd/etcd.conf.yml<<EOF
name: 'default'
data-dir: /var/lib/etcd
enable-v2: false
debug: false
logger: zap
log-outputs: [stderr]
listen-client-urls: http://0.0.0.0:2379
EOF


cat > /lib/systemd/system/etcd.service<<EOF
[Unit]
Description=etcd
Documentation=https://github.com/coreos/etcd
After=network.target
After=network-online.target
Wants=network-online.target
[Service]
Type=notify
ExecStart=/usr/local/bin/etcd --config-file /etc/etcd/etcd.conf.yml
Restart=on-failure
RestartSec=10s
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOF


systemctl daemon-reload
if systemctl is-active etcd &>/dev/null; then
    systemctl restart etcd
else
    systemctl enable --now etcd
fi
systemctl status -l etcd --no-pager
}

fun_install