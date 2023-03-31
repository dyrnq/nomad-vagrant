#!/usr/bin/env bash


iface="${iface:-enp0s8}"
ver=${ver:-v1.6.20}
runc_ver=${runc_ver:-v1.1.4}
nerdctl_ver=${nerdctl_ver:-v1.2.1}
buildkit_ver=${buildkit_ver:-v0.11.5}
cni_ver=${cni_ver:-v1.2.0}
flannel_cni_ver=${flannel_cni_ver:-v1.1.2}

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
local nerdctl_ver_nov

ver_nov="${ver:1}"
nerdctl_ver_nov="${nerdctl_ver:1}"

#local runc_ver_nov
#local buildkit_ver_nov
#local cni_ver_nov
#local flannel_cni_ver_nov
#runc_ver_nov=${runc_ver:1}
#buildkit_ver_nov=${buildkit_ver:1}
#cni_ver_nov=${cni_ver:1}
#flannel_cni_ver_nov=${flannel_cni_ver:1}




mkdir -p /opt/cni/bin
mkdir -p /etc/cni/net.d
wget --continue https://files.m.daocloud.io/github.com/containerd/containerd/releases/download/"${ver}"/containerd-"${ver_nov}"-linux-amd64.tar.gz
wget --continue https://files.m.daocloud.io/github.com/opencontainers/runc/releases/download/"${runc_ver}"/runc.amd64
wget --continue https://files.m.daocloud.io/github.com/containerd/nerdctl/releases/download/"${nerdctl_ver}"/nerdctl-"${nerdctl_ver_nov}"-linux-amd64.tar.gz
wget --continue https://files.m.daocloud.io/github.com/moby/buildkit/releases/download/"${buildkit_ver}"/buildkit-"${buildkit_ver}".linux-amd64.tar.gz
wget --continue https://files.m.daocloud.io/github.com/containernetworking/plugins/releases/download/"${cni_ver}"/cni-plugins-linux-amd64-"${cni_ver}".tgz
wget --continue https://files.m.daocloud.io/github.com/flannel-io/cni-plugin/releases/download/"${flannel_cni_ver}"/flannel-amd64
tar -xvz -f cni-plugins-linux-amd64-"${cni_ver}".tgz -C /opt/cni/bin


install -m 755 flannel-amd64 /opt/cni/bin/flannel

tar -xvf containerd-"${ver_nov}"-linux-amd64.tar.gz -C /usr/local
install -m 755 runc.amd64 /usr/bin/runc

tar -xvf nerdctl-"${nerdctl_ver_nov}"-linux-amd64.tar.gz -C /usr/local/bin
chmod 700 /usr/local/bin/nerdctl

tar -xvf buildkit-"${buildkit_ver}".linux-amd64.tar.gz -C /usr/local


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

