#!/usr/bin/env bash


iface="${iface:-enp0s8}"
encrypt="${encrypt:-goplCZgdmOFMZ2Q43To0jw==}"
SERVER=${SERVER:-}
ver=${ver:-1.14.4}

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
        --encrypt)
            encrypt="$2"
            shift
            ;;
		--server)
			SERVER=1
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

is_server() {
	if [ -z "$SERVER" ]; then
		return 1
	else
		return 0
	fi
}

fun_install() {
    mkdir -p /var/lib/consul
    mkdir -p /var/log/consul
    mkdir -p /etc/consul
    mkdir -p /var/lib/nomad
    mkdir -p /var/log/nomad
    mkdir -p /etc/nomad
    chmod a+w /etc/nomad


    echo "Installing Consul..."
    curl -sSL https://releases.hashicorp.com/consul/${ver}/consul_${ver}_linux_amd64.zip -o /tmp/consul.zip
    unzip -o -d /tmp /tmp/consul.zip
    install /tmp/consul /usr/bin/consul

cat > /lib/systemd/system/consul.service <<EOF
[Unit]
Description=consul
Documentation=https://github.com/hashicorp/consul
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/consul agent -config-dir /etc/consul/ -bind=$ip4 -node="$(hostname)"
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
RestartSec=10s
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

if is_server; then
cat >/etc/consul/consul.json<<EOF
{
    "bootstrap_expect": 3,
    "server": true,
    "client_addr": "0.0.0.0",
    "datacenter": "dc1",
    "data_dir": "/var/lib/consul",
    "dns_config": {
      "enable_truncate": true,
      "only_passing": true
    },
    "encrypt": "$encrypt",
    "leave_on_terminate": true,
    "rejoin_after_leave": true,
    "ui": true,
    "enable_debug": false,
    "auto_reload_config": true,
    "retry_join": ["192.168.33.4","192.168.33.5","192.168.33.6"],
    "retry_interval": "30s",
    "start_join": ["192.168.33.4","192.168.33.5","192.168.33.6"],
    "disable_update_check": true,
    "log_level": "INFO",
    "log_file": "/var/log/consul/",
    "log_rotate_duration": "24h"
}
EOF
else
cat >/etc/consul/consul.json<<EOF
{
    "server": false,
    "client_addr": "0.0.0.0",
    "datacenter": "dc1",
    "data_dir": "/var/lib/consul",
    "dns_config": {
      "enable_truncate": true,
      "only_passing": true
    },
    "encrypt": "$encrypt",
    "leave_on_terminate": true,
    "rejoin_after_leave": true,
    "ui": true,
    "enable_debug": false,
    "auto_reload_config": true,
    "retry_join": ["192.168.33.4","192.168.33.5","192.168.33.6"],
    "retry_interval": "30s",
    "start_join": ["192.168.33.4","192.168.33.5","192.168.33.6"],
    "disable_update_check": true,
    "log_level": "INFO",
    "log_file": "/var/log/consul/",
    "log_rotate_duration": "24h"
}
EOF
fi

systemctl daemon-reload
if systemctl is-active consul &>/dev/null; then
    systemctl restart consul
else
    systemctl enable --now consul 
fi
systemctl status -l consul --no-pager
}


fun_install