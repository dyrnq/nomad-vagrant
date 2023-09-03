#!/usr/bin/env bash


fun_clickhouse(){

# https://clickhouse.com/docs/zh/getting-started/tutorial
apt-get install -y apt-transport-https ca-certificates dirmngr
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 8919F6BD2B48D754

echo "deb https://packages.clickhouse.com/deb stable main" | tee /etc/apt/sources.list.d/clickhouse.list
apt-get update

apt-get install -y clickhouse-server clickhouse-client
# ClickHouse数据库有以下默认端口：

# https://clickhouse.com/docs/en/guides/sre/network-ports

}


fun_clickhouse


# https://mp.weixin.qq.com/s/FscDJpjN2dFObFHQE0KBxg
# https://blog.51cto.com/u_15767560/5629023