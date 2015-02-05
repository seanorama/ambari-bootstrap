#!/usr/bin/env bash
#
# Deploys a cluster with Ambari Blueprint Recommendations
#   * No blueprints required!

set -o errexit
set -o nounset
set -o pipefail

## allowed overrides for these
node_count=${node_count:-''}
ambari_services=(${ambari_services[*]:-FALCON FLUME GANGLIA HBASE HDFS HIVE KAFKA KERBEROS MAPREDUCE2
    NAGIOS OOZIE PIG SLIDER SQOOP STORM TEZ YARN ZOOKEEPER})
ambari_stack_name="${ambari_stack_name:-HDP}"
ambari_stack_version="${ambari_stack_version:-2.2}"
ambari_host=${ambari_host:-localhost}
ambari_password=${ambari_password:-admin}
cluster_name=${cluster_name:-hadoop}
ambari_blueprint_name="${ambari_blueprint_name:-recommended}"

## for curl requests
ambari_curl="curl -su admin:${ambari_password} -H X-Requested-By:ambari"
ambari_api="http://${ambari_host}:8080/api/v1"

## magic
__dir=$( cd "$(dirname "$0")" ; pwd )
tmp_dir="$(mktemp -d ${__dir}/ambari-bootstrap-$(date +%Y%m%d-%H%M%S)-XXX)"

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

nodes=($(${ambari_curl} ${ambari_api}/hosts | python -c '
    import json,sys; obj=json.load(sys.stdin)
    for y in [x["Hosts"]["host_name"] for x in obj["items"]]:
        print y
'))

# TODO: put a while loop to not continue until the provided node count matches the number of registered nodes
echo ${nodes[*]}
node_count_actual=$(echo ${nodes[*]} | wc -w)

# proceeding with building the cluster
ambari_services_json="[ $(for service in ${ambari_services[*]}; do echo \"${service}\" ; done | paste -sd,) ]"
ambari_hosts_json="[ $(for node in ${nodes[*]}; do echo \"${node}\" ; done | paste -sd,) ]"

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
echo -e "\n\nCluster build status at: ${status_url}"

## TODO: put a wait loop here until the job is completed or failed

exit 0
