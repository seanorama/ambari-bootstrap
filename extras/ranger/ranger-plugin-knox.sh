#!/usr/bin/env bash

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__root="$(cd "$(dirname "${__dir}")" && pwd)" # <-- change this
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"

source ${__dir}/../ambari_functions.sh

ambari_configs

defaultfs=$(${ambari_config_get} core-site | awk -F'"' '$2 == "fs.defaultFS" {print $4}' | head -1)


## Ranger Knox Plugin
${ambari_config_set} ranger-knox-audit xasecure.audit.destination.db true
${ambari_config_set} ranger-knox-audit xasecure.audit.destination.hdfs.dir "${defaultfs}/ranger/audit"
${ambari_config_set} ranger-knox-audit xasecure.audit.is.enabled true
${ambari_config_set} ranger-knox-audit xasecure.audit.provider.summary.enabled true
#${ambari_config_set} ranger-knox-plugin-properties REPOSITORY_CONFIG_USERNAME rangeradmin
#${ambari_config_set} ranger-knox-plugin-properties REPOSITORY_CONFIG_PASSWORD BadPass#1
${ambari_config_set} ranger-knox-plugin-properties common.name.for.certificate " "
${ambari_config_set} ranger-knox-plugin-properties ranger-knox-plugin-enabled yes
