#!/usr/bin/env bash

nerdctl network inspect flash &>/dev/null || nerdctl network create --subnet 172.18.0.0/16 --gateway 172.18.0.1 --driver bridge flash

mkdir -p $HOME/var/lib/zookeeper/data/;
mkdir -p $HOME/var/lib/zookeeper/datalog/;
nerdctl rm -f zookeeper 2>/dev/null || true;
nerdctl run -d --name zookeeper --restart always --network flash \
--log-driver=json-file \
--log-opt=max-size=100m \
--log-opt=max-file=10 \
-e ALLOW_ANONYMOUS_LOGIN=yes \
-v $HOME/var/lib/zookeeper/data:/data \
-v $HOME/var/lib/zookeeper/datalog:/datalog \
-p 2181:2181 \
zookeeper:3.9.0




mkdir -p $HOME/var/lib/kafka/ && chown 1001:1001 $HOME/var/lib/kafka/


nerdctl rm -f kafka 2>/dev/null || true;

nerdctl run -d --name kafka --restart always --network flash \
--log-driver=json-file \
--log-opt=max-size=100m \
--log-opt=max-file=10 \
-e KAFKA_CFG_ZOOKEEPER_CONNECT=192.168.33.14:2181 \
-e KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE=true \
-e KAFKA_CFG_ADVERTISED_LISTENERS=PLAINTEXT://192.168.33.14:9092 \
-e KAFKA_CFG_LISTENERS=PLAINTEXT://0.0.0.0:9092 \
-v $HOME/var/lib/kafka:/bitnami/kafka \
-p 9092:9092 \
bitnami/kafka:3.4.1-debian-11-r81







nerdctl rm -f kafka-ui 2>/dev/null || true;
nerdctl run -d --name kafka-ui --restart always --network flash \
--log-driver=json-file \
--log-opt=max-size=100m \
--log-opt=max-file=10 \
-e LOGGING_LEVEL_COM_PROVECTUS=INFO \
-e KAFKA_CLUSTERS_0_NAME=local \
-e KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS=192.168.33.14:9092 \
-p 28888:8080 \
provectuslabs/kafka-ui:latest