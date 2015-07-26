#!/usr/bin/env bash

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__root="$(cd "$(dirname "${__dir}")" && pwd)" # <-- change this
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"

source ${__dir}/../ambari_functions.sh

ambari-configs

defaultfs=$(${ambari_config_get} core-site | awk -F'"' '$2 == "fs.defaultFS" {print $4}' | head -1)

## Ranger Hive Plugin
${ambari_config_set} ranger-hive-audit xasecure.audit.destination.db true
${ambari_config_set} ranger-hive-audit xasecure.audit.destination.hdfs.dir "${defaultfs}/ranger/audit"
${ambari_config_set} ranger-hive-audit xasecure.audit.is.enabled true
${ambari_config_set} ranger-hive-audit xasecure.audit.provider.summary.enabled true
${ambari_config_set} ranger-hive-plugin-properties common.name.for.certificate " "

${ambari_config_set} hive-env hive_security_authorization Ranger
${ambari_config_set} hive-site hive.security.authorization.enabled true
${ambari_config_set} hive-site hive.server2.enable.doAs false
${ambari_config_set} hiveserver2-site hive.security.authorization.manager org.apache.ranger.authorization.hive.authorizer.RangerHiveAuthorizerFactory
${ambari_config_set} hiveserver2-site hive.security.authorization.enabled true

${ambari_config_set} ranger-hive-plugin-properties ranger-hive-plugin-enabled yes

