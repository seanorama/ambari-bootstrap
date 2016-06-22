#!/usr/bin/env bash

## This will enable the Hive Bridge to Atlas which allows
##   Atlas to capture metadata & lineage automatically from Hive

##-----------------------------------------------------------------------

## Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"

source ${__dir}/../ambari_functions.sh
ambari_configs

atlas_host=$(${ambari_config_get} application-properties | awk -F'"' '$2 == "atlas.server.bind.address" {print $4}' | head -1)
atlas_port=$(${ambari_config_get} atlas-env | awk -F'"' '$2 == "metadata_port" {print $4}' | head -1)
hive_hooks=$(${ambari_config_get} hive-site | awk -F'"' '$2 == "hive.exec.post.hooks" {print $4}' | head -1)

${ambari_config_set} hive-site atlas.cluster.name ${ambari_cluster}
${ambari_config_set} hive-site atlas.rest.address http://${atlas_host}:${atlas_port}
${ambari_config_set} hive-site hive.exec.post.hooks "${hive_hooks},org.apache.atlas.hive.hook.HiveHook"
${ambari_config_set} hive-site atlas.hook.hive.synchronous true
${ambari_config_set} atlas-env metadata_classpath "/usr/hdp/current/atlas/hook/hive"
