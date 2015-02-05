#!/usr/bin/env bash
#
# Deploys a cluster with Ambari Blueprint Recommendations
#   * No blueprints required!

set -o errexit
set -o nounset
set -o pipefail

## allowed overrides for these
host_count=${host_count:-ask} ## options: the count of hosts, 'ask', 'skip'
ambari_services=(${ambari_services[*]:-FALCON FLUME GANGLIA HBASE HDFS HIVE KAFKA KERBEROS MAPREDUCE2
    NAGIOS OOZIE PIG SLIDER SQOOP STORM TEZ YARN ZOOKEEPER})
ambari_stack_name="${ambari_stack_name:-HDP}"
ambari_stack_version="${ambari_stack_version:-2.2}"
ambari_server=${ambari_server:-localhost}
ambari_password=${ambari_password:-admin}
cluster_name=${cluster_name:-hdp}
ambari_blueprint_name="${ambari_blueprint_name:-recommended}"

## for curl requests
ambari_curl="curl -su admin:${ambari_password} -H x-requested-by:ambari"
ambari_api="http://${ambari_server}:8080/api/v1"

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


hosts_regd() {
    hosts_regd=($(${ambari_curl} ${ambari_api}/hosts | python -c '
import json,sys; obj=json.load(sys.stdin)
for y in [x["Hosts"]["host_name"] for x in obj["items"]]:
    print y
'))
}

host_check() {
    sleep_seconds=15
    while true; do
        hosts_regd
        hosts_regd_count=$(echo ${hosts_regd[*]} | wc -w)
        printf "\n$(date)\n\n"
        printf "# Checking the number of registered hosts before proceeding with deployment\n"
        printf "===========================================================================\n\n"
        printf "  * Hosts expected:   ${host_count}\n"
        printf "  * Hosts registered: ${hosts_regd_count}\n\n"
        if [ ${hosts_regd_count} -eq ${host_count} ]; then
            printf "Success: All hosts have checked in!\n\n"
            printf "# Deploying Hortonworks Data Platform using Ambari Blueprint Recommendations\n"
            printf "============================================================================\n\n"
            break
        else
            printf "Some hosts have not checked in.\n\n"
            printf "Notice: We will check again in ${sleep_seconds} seconds.\n"
            sleep ${sleep_seconds}
            clear
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
fi

# proceeding with building the cluster
ambari_services_json="[ $(for service in ${ambari_services[*]}; do echo \"${service}\" ; done | paste -sd,) ]"
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

## merge recommendations with custom configuration
python ${__dir}/create_blueprint.py \
    --conf_recommendation ${tmp_dir}/configurations.json \
    --host_recommendation ${tmp_dir}/host_groups.json \
    --blueprint ${tmp_dir}/blueprint.json \
    --cluster_template ${tmp_dir}/cluster.json \
    --blueprint_name ${ambari_blueprint_name} \
    --custom_configuration ${__dir}/configuration-custom.json

## upload the generated blueprint & create the cluster
${ambari_curl} ${ambari_api}/blueprints/${ambari_blueprint_name} -d @${tmp_dir}/blueprint.json
create_cluster=$(${ambari_curl} ${ambari_api}/clusters/${cluster_name} -d @${tmp_dir}/cluster.json)

## print the status
status_url=$(echo ${create_cluster} | json_get_value href | tr -d \')
${ambari_curl} ${status_url} | json_get_value Requests
printf "\n\nCluster build status at: ${status_url}"


exit 0
