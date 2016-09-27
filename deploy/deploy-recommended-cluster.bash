#!/usr/bin/env bash
#
# Deploys a cluster with Ambari Blueprint Recommendations
#   * No blueprints required!

set -o errexit
set -o nounset
set -o pipefail

## allowed overrides for these
host_count=${host_count:-ask} ## options: the count of hosts, 'ask', 'skip'
ambari_services=${ambari_services:-AMBARI_METRICS FALCON FLUME
    HBASE HDFS HIVE KAFKA KNOX MAPREDUCE2 OOZIE PIG SLIDER SPARK SQOOP
    STORM TEZ YARN ZOOKEEPER}
: ${ambari_stack_name:="HDP"}
: ${ambari_stack_version:="2.4"}
: ${ambari_server:="localhost"}
: ${ambari_password:="admin"}
: ${ambari_protocol:="http"}
: ${ambari_port:="8080"}
: ${cluster_name:="hdp"}
: ${ambari_blueprint_name:="recommended"}
: ${deploy:=true}
: ${recommendation_strategy:="false"}  ## valid options:
## NEVER_APPLY, ONLY_STACK_DEFAULTS_APPLY, ALWAYS_APPLY, ALWAYS_APPLY_DONT_OVERRIDE_CUSTOM_VALUES

## for curl requests
ambari_curl="curl -ksSu admin:${ambari_password} -H x-requested-by:ambari"
ambari_api="${ambari_protocol}://${ambari_server}:${ambari_port}/api/v1"

## magic
__dir=$( cd "$(dirname "$0")" ; pwd )
tmp_dir="$(mktemp -d ${__dir}/tempdir.ambari-bootstrap-$(date +%Y%m%d-%h%m%s)-XXX)"

## functions
command_exists() {
    command -v "$@" > /dev/null 2>&1
}
json_get_value() {
    python -c 'import sys,json; from pprint import pprint; pprint(json.load(sys.stdin)[sys.argv[1]])' ${@}
}

## check requirements
command_exists curl 2>/dev/null || { echo >&2 "I require curl but it's not installed.  Aborting."; exit 1; }
# TODO: need to check python arg_parse

if ! python -c 'import argparse' && [[ -x $(which yum) ]]; then
    printf "FAIL: I require 'python-argparse'. On yum based systems, install with:\n"
    printf "yum install -y python-argparse\n"
    exit 1
fi


hosts_regd() {
    hosts_regd=($(${ambari_curl} ${ambari_api}/hosts | python -c '
import json,sys; obj=json.load(sys.stdin)
for y in [x["Hosts"]["host_name"] for x in obj["items"]]:
    print y
'))
}

host_check() {
    #SLEEP=10; COUNT=60
    #until $(: TODO:equal of hosts); do
        #sleep ${SLEEP}
        #let COUNT=COUNT-1
        #if [ $COUNT -eq 0 ]; then
            #echo "Timeout: All Ambari-Agents did not register"
            #exit 1
        #fi
    #done
    #unset SLEEP; unset COUNT

    SLEEP=10
    while true; do
        hosts_regd
        hosts_regd_count=$(echo ${hosts_regd[*]} | wc -w)
        if [ ${hosts_regd_count} -eq ${host_count} ]; then
            printf "## Success: ${hosts_regd_count} of ${host_count} registered.\n"
            printf "##          Deploying generated Ambari Blueprint\n"
            break
        else
            printf "## Waiting: ${hosts_regd_count} of ${host_count} Ambari-Agents have registered.\n\n"
            sleep ${SLEEP}
        fi
    done
}

shopt -s extglob
verify_host_count() {
    case ${host_count} in
        +([0-9]))
            printf "Deploying the cluster once ${host_count} hosts are registered.\n\n"
            ;;
        skip)
            printf "Skipping host count check, proceeding immediately.\n"
            ;;
        ask)
            ;;
        *)
            printf "\'${host_count}\' is not a valid host_count\n"
            printf "Accepted values: the number of hosts, 'skip'\n"
            export host_count=ask
            ;;
    esac
}

verify_host_count
while [ ${host_count} = "ask" ]; do
    read -t 30 -p '
        Please enter the number of hosts you are expecting,
        or enter "skip" to proceed without the host check.

        This prompt when timeout in 30 seconds.

        host_count: ' host_count
    verify_host_count
done

if [ "${host_count}" != "skip" ]; then
    host_check
else
    hosts_regd
fi

# proceeding with building the cluster
ambari_services_json="[ \"$(sed 's/ /\",\"/g' <<< ${ambari_services})\" ]"
ambari_hosts_json="[ $(for host in ${hosts_regd[*]}; do echo \"${host}\" ; done | paste -sd,) ]"

## get recommendations
for recommend in host_groups configurations; do
    cat > ${tmp_dir}/request-${recommend}.json <<EOF
    {
      "recommend" : "${recommend}",
      "services" : ${ambari_services_json},
      "hosts" : ${ambari_hosts_json}
    }
EOF
    ${ambari_curl} ${ambari_api}/stacks/${ambari_stack_name}/versions/${ambari_stack_version}/recommendations \
        -d @"${tmp_dir}/request-${recommend}.json" > ${tmp_dir}/${recommend}.json
done

if [ "${recommendation_strategy}" != 'false' ]; then
cat > ${tmp_dir}/configurations.json <<EOF
{ "resources" : [ {
  "Versions" : { "stack_name" : "${ambari_stack_name}", "stack_version" : "${ambari_stack_version}" },
  "recommendations" : { "blueprint" : { "configurations" : { "cluster-env" : {
    "properties" : { "ambari-bootstrap-filler" :
      "this does nothing but is needed to merge configurations"
}}}}}}]}
EOF
fi

## merge recommendations with custom configuration
python ${__dir}/create_blueprint.py \
    --conf_recommendation ${tmp_dir}/configurations.json \
    --host_recommendation ${tmp_dir}/host_groups.json \
    --blueprint ${tmp_dir}/blueprint.json \
    --cluster_template ${tmp_dir}/cluster.json \
    --blueprint_name ${ambari_blueprint_name} \
    --recommendation_strategy "${recommendation_strategy}" \
    --custom_configuration ${__dir}/configuration-custom.json

if [ "${deploy}" = true ]; then
    ## upload the generated blueprint & create the cluster
    ${ambari_curl} ${ambari_api}/blueprints/${ambari_blueprint_name} -d @${tmp_dir}/blueprint.json
    ${ambari_curl} ${ambari_api}/clusters/${cluster_name} -d @${tmp_dir}/cluster.json

    ## print the status
    status_url=${ambari_api}/clusters/${cluster_name}/requests/1
    ${ambari_curl} ${status_url} | json_get_value Requests
    printf "\n\nCluster build status at: ${status_url}\n\n"
fi

exit 0

