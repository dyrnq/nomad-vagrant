#!/usr/bin/env bash


iface="${iface:-enp0s8}"
ver=${ver:-v1.6.18}

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

#ip4=$(/sbin/ip -o -4 addr list "${iface}" | awk '{print $4}' |cut -d/ -f1 | head -n1);


command_exists() {
    command -v "$@" > /dev/null 2>&1
}



fun_install(){
local ver_nov
ver_nov="${ver:1}"    
mkdir -p /opt/cni/bin
mkdir -p /etc/cni/net.d
wget --continue https://files.m.daocloud.io/github.com/containerd/containerd/releases/download/"${ver}"/containerd-"${ver_nov}"-linux-amd64.tar.gz
wget --continue https://files.m.daocloud.io/github.com/opencontainers/runc/releases/download/v1.1.4/runc.amd64
wget --continue https://files.m.daocloud.io/github.com/containerd/nerdctl/releases/download/v1.2.0/nerdctl-1.2.0-linux-amd64.tar.gz
wget --continue https://files.m.daocloud.io/github.com/moby/buildkit/releases/download/v0.11.2/buildkit-v0.11.2.linux-amd64.tar.gz
wget --continue https://files.m.daocloud.io/github.com/containernetworking/plugins/releases/download/v1.2.0/cni-plugins-linux-amd64-v1.2.0.tgz
wget --continue https://files.m.daocloud.io/github.com/flannel-io/cni-plugin/releases/download/v1.1.2/flannel-amd64
tar -xvz -f cni-plugins-linux-amd64-v1.2.0.tgz -C /opt/cni/bin


install -m 755 flannel-amd64 /opt/cni/bin/flannel

tar -xvf containerd-"${ver_nov}"-linux-amd64.tar.gz -C /usr/local
install -m 755 runc.amd64 /usr/bin/runc

tar -xvf nerdctl-1.2.0-linux-amd64.tar.gz -C /usr/local/bin
chmod 700 /usr/local/bin/nerdctl

tar -xvf buildkit-v0.11.2.linux-amd64.tar.gz -C /usr/local


cat >/lib/systemd/system/containerd.service<<EOF
# Copyright The containerd Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Service]
#uncomment to enable the experimental sbservice (sandboxed) version of containerd/cri integration
#Environment="ENABLE_CRI_SANDBOXES=sandboxed"
ExecStartPre=-/sbin/modprobe overlay
ExecStartPre=-/sbin/modprobe br_netfilter
ExecStart=/usr/local/bin/containerd

Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=infinity
# Comment TasksMax if your systemd version does not supports it.
# Only systemd 226 and above support this version.
TasksMax=infinity
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target

EOF


systemctl daemon-reload
if systemctl is-active containerd &>/dev/null; then
    systemctl restart containerd
else
    systemctl enable --now containerd
fi
systemctl status -l containerd --no-pager

}

fun_install

