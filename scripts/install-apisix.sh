#!/usr/bin/env bash



iface="${iface:-eth1}"
apisix_home="${apisix_home:-/opt/apisix}"
apisix_dashboard_home="${apisix_dashboard_home:-/opt/apisix-dashboard}"
apisix_image="${apisix_image:-apache/apisix:3.4.0-debian}"
apisix_dashboard_image="${apisix_dashboard_image:-apache/apisix-dashboard:3.0.1-alpine}"



while [ $# -gt 0 ]; do
    case "$1" in
        --iface|-i)
            iface="$2"
            shift
            ;;
        --apisix-home|-h)
            apisix_home="$2"
            shift
            ;;
        --apisix-dashboard-home|-H)
            apisix_dashboard_home="$2"
            shift
            ;;
        --apisix-image|-m)
            apisix_image="$2"
            shift
            ;;
        --apisix-dashboard-image|-M)
            apisix_dashboard_image="$2"
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




fun_install() {
mkdir -p ${apisix_home}/
mkdir -p ${apisix_home}/conf
mkdir -p ${apisix_dashboard_home}/conf

## https://github.com/apache/apisix/blob/master/conf/config.yaml
cat > ${apisix_home}/conf/config.yaml <<EOF
apisix:
  node_listen: 9080
  enable_ipv6: false


deployment:
  role: traditional
  role_traditional:
    config_provider: etcd

  etcd:
    host: ["http://192.168.33.4:2379"]
    prefix: "/apisix"
    timeout: 30
  admin:
    allow_admin:
      - 192.168.0.0/16
      - 127.0.0.0/24  
    admin_key:
      - name: admin
        key: edd1c9f034335f136f87ad84b625c8f1  # using fixed API token has security risk, please update it when you deploy to production environment
        role: admin

plugin_attr:
  prometheus:
    export_addr:
      ip: "0.0.0.0"
      port: 9091

discovery:                       # service discovery center
  dns:
    servers:
      - "127.0.0.1:8600"         # use the real address of your dns server
  consul:
    servers:
      - "http://127.0.0.1:8500"
EOF


nerdctl rm -f apisix 2>/dev/null || true
nerdctl run -d --name apisix \
--restart always \
--log-driver=json-file \
--log-opt=max-size=100m \
--log-opt=max-file=10 \
--net host \
--privileged \
--ulimit nofile=40000:40000 \
-v ${apisix_home}/conf/config.yaml:/usr/local/apisix/conf/config.yaml  \
${apisix_image}





secret=$(openssl rand -base64 32)
secret="secret"
## https://github.com/apache/apisix-dashboard/blob/master/api/conf/conf.yaml
cat > ${apisix_dashboard_home}/conf/conf.yaml <<EOF
conf:
  listen:
    host: 0.0.0.0
    port: 9000
  allow_list:
    - 0.0.0.0/0
  etcd:
    endpoints: ["http://192.168.33.4:2379"]
    prefix: /apisix
  log:
    error_log:
      level: warn
      file_path:
        /dev/stderr
    access_log:
      file_path:
        /dev/stdout
  max_cpu: 0
  
authentication:
  secret:
    ${secret}
  expire_time: 3600
  users:
    - username: admin
      password: admin
plugins:
  - api-breaker
  - authz-keycloak
  - basic-auth
  - batch-requests
  - consumer-restriction
  - cors
  # - dubbo-proxy
  - echo
  # - error-log-logger
  # - example-plugin
  - fault-injection
  - grpc-transcode
  - hmac-auth
  - http-logger
  - ip-restriction
  - jwt-auth
  - kafka-logger
  - key-auth
  - limit-conn
  - limit-count
  - limit-req
  # - log-rotate
  # - node-status
  - openid-connect
  - prometheus
  - proxy-cache
  - proxy-mirror
  - proxy-rewrite
  - redirect
  - referer-restriction
  - request-id
  - request-validation
  - response-rewrite
  - serverless-post-function
  - serverless-pre-function
  # - skywalking
  - sls-logger
  - syslog
  - tcp-logger
  - udp-logger
  - uri-blocker
  - wolf-rbac
  - zipkin
  - server-info
  - traffic-split
  - elasticsearch-logge
  - openfunction
  - tencent-cloud-cls
  - ai
  - cas-auth  
EOF


nerdctl rm -f apisix-dashboard 2>/dev/null || true
nerdctl run -d --name apisix-dashboard \
--restart always \
--log-driver=json-file \
--log-opt=max-size=100m \
--log-opt=max-file=10 \
--net host \
--privileged \
-e TZ=Asia/Shanghai \
-v ${apisix_dashboard_home}/conf/conf.yaml:/usr/local/apisix-dashboard/conf/conf.yaml  \
${apisix_dashboard_image}


}


fun_install