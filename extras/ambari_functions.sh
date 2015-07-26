
## really bad hacked scripts that I've written dozens of times and
##   finally going to start consolidating ...

## todo: include my code that's in bdutil:
##   https://github.com/GoogleCloudPlatform/bdutil/blob/master/platforms/hdp/ambari_functions.sh

source ~/.ambari.conf

ambari_user=${ambari_user:-admin}
ambari_pass=${ambari_pass:-admin}
ambari_protocol=${ambari_protocol:-http}
ambari_host=${ambari_host:-localhost}
ambari_port=${ambari_port:-8080}
ambari_api="${ambari_protocol}://${ambari_host}:${ambari_port}/api/v1"
ambari_curl="curl -ksSu ${ambari_user}:${ambari_pass} -H x-requested-by:sean ${ambari_api}"

## auto-detect cluster

ambari-get-cluster() {
  ambari_cluster=$(${ambari_curl}/clusters \
      | python -c 'import sys,json; \
            print json.load(sys.stdin)["items"][0]["Clusters"]["cluster_name"]')
}

ambari-configs() {
  ambari-get-cluster
  ambari_configs_sh="/var/lib/ambari-server/resources/scripts/configs.sh \
    -u ${ambari_user} -p ${ambari_pass}"
  ambari_config_set="${ambari_configs_sh} set ${ambari_host} ${ambari_cluster}"
  ambari_config_get="${ambari_configs_sh} get ${ambari_host} ${ambari_cluster}"

  #defaultfs=$(${config_get} core-site | awk -F'"' '$2 == "fs.defaultFS" {print $4}' | head -1)
}

ambari-change-pass() {
  # expects: ambari-change-pass username oldpass newpass
read -r -d '' body <<EOF
{ "Users": { "user_name": "$1", "old_password": "$2", "password": "$3" }}
EOF

  echo ${body}
  echo "${body}" | ${ambari_curl}/users/$1 \
    -v -X PUT -d @-
}
