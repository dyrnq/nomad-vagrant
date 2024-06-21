#!/usr/bin/env bash

net=${net:-flannel}
while [ $# -gt 0 ]; do
    case "$1" in
        --net|--cni)
            net="$2"
            shift
            ;;
        --*)
            echo "Illegal option $1"
            ;;
    esac
    shift $(( $# > 0 ? 1 : 0 ))
done



nerdctl rm -f test &>/dev/null || true
nerdctl run --net ${net} -d --name test -v /opt:/opt -p 9992:80 --ulimit nofile=40000:40000 kennethreitz/httpbin

nerdctl exec -i test bash <<'EOF'
sed -i 's@//.*archive.ubuntu.com@//mirrors.ustc.edu.cn@g' /etc/apt/sources.list
apt update -y
apt -y install iproute2 iputils-ping netcat
ip4=$(/sbin/ip -o -4 addr list eth0 | awk '{print $4}' |cut -d/ -f1 | head -n1);
echo $ip4 > /opt/ip.txt
EOF

cip=$(cat /opt/ip.txt)
echo "${cip}"
ping -c 3 "${cip}"

nerdctl exec -i test bash <<'EOF'
ping -c 3 192.168.33.4
ping -c 3 192.168.33.5
ping -c 3 192.168.33.6
EOF

nc -nvz ${cip} 80
nc -nvz 192.168.33.4 9992
nc -nvz 192.168.33.5 9992
nc -nvz 192.168.33.6 9992

