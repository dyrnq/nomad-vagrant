#!/usr/bin/env bash


iface="${iface:-enp0s8}"
encrypt="${encrypt:-goplCZgdmOFMZ2Q43To0jw==}"
SERVER=${SERVER:-}
ver=${ver:-1.4.3}

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


    echo "Installing Nomad..."
    curl -sSL https://releases.hashicorp.com/nomad/${ver}/nomad_${ver}_linux_amd64.zip -o /tmp/nomad.zip
    unzip -o -d /tmp /tmp/nomad.zip
    install /tmp/nomad /usr/bin/nomad

cat > /lib/systemd/system/nomad.service <<EOF
[Unit]
Description=Nomad Agent
# Requires=consul-online.target
# After=consul-online.target

[Service]
Restart=on-failure
EnvironmentFile=-/etc/nomad/nomad.conf
ExecStart=/usr/bin/nomad agent -config /etc/nomad -node="$(hostname)" $FLAGS
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
KillSignal=SIGTERM
User=root
Group=root

LimitNOFILE=65536
LimitNPROC=infinity
RestartSec=2
TasksMax=infinity
OOMScoreAdjust=-1000

[Install]
WantedBy=multi-user.target
EOF
# rm -rf /etc/nomad/nomad.json
# rm -rf /etc/nomad/nomad.hcl
# rm -rf /etc/nomad/10-nomad.hcl
if is_server; then
cat >/etc/nomad/nomad.hcl<<EOF
log_level = "INFO"
log_file = "/var/log/nomad/"
log_rotate_duration = "24h"
data_dir = "/var/lib/nomad"
bind_addr = "0.0.0.0"
enable_debug = false
advertise {
  http = "$ip4"
  rpc = "$ip4"
  serf = "$ip4"
}
ports {
  http = 4646
  rpc  = 4647
  serf = 4648
}
client {
  enabled = true
  servers = ["192.168.33.4:4647","192.168.33.5:4647","192.168.33.6:4647"]
  options {
    "driver.raw_exec.enable" = "1"
  }
}
server {
  enabled = true
  bootstrap_expect = 3
  server_join {
    retry_join = [ "192.168.33.4:4648", "192.168.33.5:4648", "192.168.33.6:4648" ]
    retry_max = 1
    retry_interval = "5s"
  }
}
disable_update_check = true
EOF
else
cat >/etc/nomad/nomad.hcl<<EOF
log_level = "INFO"
data_dir = "/var/lib/nomad"
log_file = "/var/log/nomad/"
log_rotate_duration = "24h"
bind_addr = "0.0.0.0"
enable_debug = false
advertise {
  http = "$ip4"
  rpc = "$ip4"
  serf = "$ip4"
}
ports {
  http = 4646
  rpc  = 4647
  serf = 4648
}
client {
  enabled = true
  servers = ["192.168.33.4:4647","192.168.33.5:4647","192.168.33.6:4647"]
  options {
    "driver.raw_exec.enable" = "1"
  }
}
disable_update_check = true
EOF
fi

systemctl daemon-reload
if systemctl is-active nomad &>/dev/null; then
    systemctl restart nomad
else
    systemctl enable --now nomad 
fi
systemctl status -l nomad --no-pager



}

fun_install_plugins(){

if systemctl is-active nomad &>/dev/null; then
    systemctl stop nomad
fi

mkdir -p /var/lib/nomad/plugins
curl -# -o /var/lib/nomad/plugins/containerd-driver -fSL --retry 10 https://files.m.daocloud.io/github.com/Roblox/nomad-driver-containerd/releases/download/v0.9.3/containerd-driver
chmod +x /var/lib/nomad/plugins/containerd-driver


cat >/etc/nomad/nomad-containerd-driver.hcl <<EOF
plugin "containerd-driver" {
  config {
    enabled = true
    containerd_runtime = "io.containerd.runc.v2"
    stats_interval = "5s"
  }
}
EOF
systemctl restart nomad
sleep 5s
systemctl status -l nomad --no-pager
}


fun_install
fun_install_plugins