#!/usr/bin/env bash

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__root="$(cd "$(dirname "${__dir}")" && pwd)" # <-- change this
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"

source ${__dir}/../ambari_functions.sh

ambari-configs

defaultfs=$(${ambari_config_get} core-site | awk -F'"' '$2 == "fs.defaultFS" {print $4}' | head -1)

sudo sudo -u hdfs hadoop fs -mkdir /ranger/audit/yarn
sudo sudo -u hdfs hadoop fs -chown yarn /ranger/audit/yarn

## Ranger YARN Plugin
${ambari_config_set} ranger-yarn-audit xasecure.audit.destination.db true
${ambari_config_set} ranger-yarn-audit xasecure.audit.destination.hdfs.dir "${defaultfs}/ranger/audit"
${ambari_config_set} ranger-yarn-audit xasecure.audit.is.enabled true
${ambari_config_set} ranger-yarn-audit xasecure.audit.provider.summary.enabled true
${ambari_config_set} ranger-yarn-plugin-properties common.name.for.certificate " "
${ambari_config_set} yarn-site yarn.acl.enable true
${ambari_config_set} yarn-site yarn.authorization-provider org.apache.ranger.authorization.yarn.authorizer.RangerYarnAuthorizer
${ambari_config_set} ranger-yarn-plugin-properties ranger-yarn-plugin-enabled Yes
