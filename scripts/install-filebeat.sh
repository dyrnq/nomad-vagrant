#!/usr/bin/env bash


mkdir -p /opt/filebeat

curl -fSL -# https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.9.1-linux-x86_64.tar.gz | tar -xvz -C /opt/filebeat --strip-components=1



mkdir -p /etc/filebeat
cat >/etc/filebeat/filebeat.yml<<'EOF'
filebeat.config:
  modules:
    #path: ${path.config}/modules.d/*.yml
    path: /opt/filebeat/modules.d/*.yml
    reload.enabled: false


filebeat.autodiscover:
  providers:
    - type: nomad
      address: http://127.0.0.1:4646
      scope: node
      hints.enabled: true
      templates:
      - config:
        - type: log
          paths:
            - "/var/lib/nomad/alloc/${data.nomad.allocation.id}/alloc/logs/${data.meta.nomad.task.name}.stderr.[0-9]*"
            - "/var/lib/nomad/alloc/${data.nomad.allocation.id}/alloc/logs/${data.meta.nomad.task.name}.stdout.[0-9]*"

output.kafka:
  enable: true
  hosts:  ["192.168.33.14:9092"]
  topic: "log_demo"
  partition.round_robin:
    reachable_only: false
  required_acks: -1
  compression: gzip
EOF


cat > /lib/systemd/system/filebeat.service<<EOF
[Unit]
Description=filebeat
Documentation=https://www.elastic.co/beats/filebeat
After=network.target
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
WorkingDirectory=/opt/filebeat
ExecStart=/opt/filebeat/filebeat -e -c /etc/filebeat/filebeat.yml
Restart=on-failure
RestartSec=10s
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOF


systemctl daemon-reload
if systemctl is-active filebeat &>/dev/null; then
    systemctl restart filebeat
else
    systemctl enable --now filebeat
fi
systemctl status -l filebeat --no-pager


# ./filebeat -e -c filebeat.yml

# https://raw.githubusercontent.com/elastic/beats/8.9/deploy/docker/filebeat.docker.yml