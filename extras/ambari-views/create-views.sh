#!/usr/bin/env bash

## Install Ambari Views
## - WARNING: This will delete existing views of the same type
##
## You'll need to update hadoop proxyuser settings for the views to work.
## Or let the script do it:
##   config_proxyuser=true ./create-views.sh

## overrides
config_proxyuser="${config_proxyuser:-false}"

########################################################################

## Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__root="$(cd "$(dirname "${__dir}")" && pwd)" # <-- change this
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"

##
source ${__dir}/../ambari_functions.sh
ambari_configs

## Get Configs
realm=$(${ambari_config_get} kerberos-env | awk -F'"' '$2 == "realm" {print $4}' | head -1)
webhdfs=$(${ambari_config_get} hdfs-site | awk -F'"' '$2 == "dfs.namenode.http-address" {print $4}' | head -1)
hive_port=$(${ambari_config_get} hive-site | awk -F'"' '$2 == "hive.server2.thrift.port" {print $4}' | head -1)
hive_host=$(${ambari_config_get} hive-site | awk -F'"' '$2 == "hive.metastore.uris" {print $4}' | head -1 | sed -e "s,^thrift://,," -e "s,:[0-9]*,,")
yarn_ats_url=$(${ambari_config_get} yarn-site | awk -F'"' '$2 == "yarn.timeline-service.webapp.address" {print $4}' | head -1 )
yarn_resourcemanager_url=$(${ambari_config_get} yarn-site | awk -F'"' '$2 == "yarn.resourcemanager.webapp.address" {print $4}' | head -1 )
webhcat_hostname=$(${ambari_curl}/clusters/${ambari_cluster}/services/HIVE/components/WEBHCAT_SERVER?fields=host_components/HostRoles/host_name\&minimal_response=true \
    | python -c 'import sys,json; \
    print json.load(sys.stdin)["host_components"][0]["HostRoles"]["host_name"]')
webhcat_port=$(${ambari_config_get} webhcat-site | awk -F'"' '$2 == "templeton.port" {print $4}' | head -1)

ambari_user=$(python -c 'from configobj import ConfigObj; \
  config = ConfigObj("/etc/ambari-server/conf/ambari.properties"); \
  print(config.get("ambari-server.user"))')

ambari_server_host_name=$(${ambari_curl}/services/AMBARI/components/AMBARI_SERVER?fields=hostComponents \
    | python -c 'import sys,json; \
    print json.load(sys.stdin)["hostComponents"][0]["RootServiceHostComponents"]["host_name"]')

if [ -z "${realm}"  ]; then
  webhdfs_auth=null
  hive_auth="auth=None"
else
  webhdfs_auth='"auth=KERBEROS;proxyuser='${ambari_user}'"'
  hive_auth="auth=KERBEROS;principal=hive/${hive_host}@${realm};hive.server2.proxy.user=\${username}"
fi

########################################################################
## update update proxyuser config
if [ "${config_proxyuser}" = true  ]; then
  ${ambari_config_set} core-site yarn.resourcemanager.proxyuser.${ambari_user}.groups "users,hadoop-users"
  ${ambari_config_set} core-site yarn.resourcemanager.proxyuser.${ambari_user}.hosts "${ambari_server_host_name}"
  ${ambari_config_set} webhcat-site webhcat.proxyuser.${ambari_user}.groups "users,hadoop-users"
  ${ambari_config_set} webhcat-site webhcat.proxyuser.${ambari_user}.hosts= "${ambari_server_host_name}"
  ${ambari_config_set} yarn-site hadoop.proxyuser.${ambari_user}.groups "users,hadoop-users"
  ${ambari_config_set} yarn-site hadoop.proxyuser.${ambari_user}.hosts "${ambari_server_host_name}"
  ${ambari_config_set} yarn-site yarn.timeline-service.http-authentication.proxyuser.${ambari_user}.groups "users,hadoop-users"
  ${ambari_config_set} yarn-site yarn.timeline-service.http-authentication.proxyuser.${ambari_user}.hosts "${ambari_server_host_name}"
fi

########################################################################
## hdfs view
read -r -d '' body <<EOF
{
  "ViewInstanceInfo": {
    "instance_name": "Files", "label": "Files", "description": "Files",
    "visible": true,
    "properties": {
      "webhdfs.username": "\${username}",
      "webhdfs.auth": ${webhdfs_auth},
      "webhdfs.url": "webhdfs://${webhdfs}"
    }
  }
}
EOF
${ambari_curl}/views/FILES/versions/1.0.0/instances/Files -X DELETE
echo "${body}" | ${ambari_curl}/views/FILES/versions/1.0.0/instances/Files -X POST -d @-

########################################################################
## hive view
read -r -d '' body <<EOF
{
  "ViewInstanceInfo": {
    "instance_name": "Hive", "label": "Hive", "description": "Hive",
    "visible": true,
    "properties": {
      "webhdfs.username": "\${username}",
      "webhdfs.auth": ${webhdfs_auth},
      "webhdfs.url": "webhdfs://${webhdfs}",
      "hive.auth": "${hive_auth}",
      "scripts.dir": "/user/\${username}/hive/scripts",
      "jobs.dir": "/user/\${username}/hive/jobs",
      "scripts.settings.defaults-file": "/user/\${username}/.\${instanceName}.defaultSettings",
      "hive.host": "${hive_host}",
      "hive.port": "${hive_port}",
      "views.tez.instance": "Tez",
      "yarn.ats.url": "http://${yarn_ats_url}",
      "yarn.resourcemanager.url": "http://${yarn_resourcemanager_url}"
    }
  }
}
EOF
${ambari_curl}/views/HIVE/versions/1.0.0/instances/Hive -X DELETE
echo "${body}" | ${ambari_curl}/views/HIVE/versions/1.0.0/instances/Hive -X POST -d @-

########################################################################
## pig view
read -r -d '' body <<EOF
{
  "ViewInstanceInfo": {
    "instance_name": "Pig", "label": "Pig", "description": "Pig",
    "visible": true,
    "properties": {
      "webhdfs.username": "\${username}",
      "webhdfs.auth": ${webhdfs_auth},
      "webhdfs.url": "webhdfs://${webhdfs}",
      "scripts.dir": "/user/\${username}/pig/scripts",
      "jobs.dir": "/user/\${username}/pig/jobs",
      "webhcat.username": "\${username}",
      "webhcat.hostname": "${webhcat_hostname}",
      "webhcat.port": "${webhcat_port}"
    }
  }
}
EOF
url="${ambari_curl}/views/PIG/versions/1.0.0/instances/Pig"
${url} -X DELETE
echo "${body}" | ${url} -X POST -d @-

########################################################################
## tez view

${ambari_config_set} core-site hadoop.http.filter.initializers org.apache.hadoop.security.AuthenticationFilterInitializer
${ambari_config_set} yarn-site yarn.resourcemanager.system-metrics-publisher.enabled "true"
${ambari_config_set} yarn-site yarn.resourcemanager.webapp.delegation-token-auth-filter.enabled "true"
${ambari_config_set} yarn-site yarn.timeline-service.enabled "true"

#dd if=/dev/urandom of=/etc/security/http_secret bs=1024 count=1
#chown hdfs:hadoop /etc/security/http_secret
#chmod 440 /etc/security/http_secret
#echo "/etc/security/http_secret"
#${ambari_config_set} core-site hadoop.http.authentication.signature.secret.file "/etc/security/http_secret"

read -r -d '' body <<EOF
{
  "ViewInstanceInfo": {
    "instance_name": "Tez", "label": "Tez", "description": "Tez",
    "visible": true,
    "properties": {
      "yarn.timeline-server.url": "http://${yarn_ats_url}",
      "yarn.resourcemanager.url": "http://${yarn_resourcemanager_url}"
    }
  }
}
EOF
url="${ambari_curl}/views/TEZ/versions/0.7.0.2.3.4.0-1310/instances/Tez"
${url} -X DELETE
echo "${body}" | ${url} -X POST -d @-

