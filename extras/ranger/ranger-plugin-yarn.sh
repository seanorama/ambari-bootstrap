#!/usr/bin/env bash

mypass=${mypass:-BadPass#1}

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__root="$(cd "$(dirname "${__dir}")" && pwd)" # <-- change this
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"

source ${__dir}/../ambari_functions.sh
ambari_configs

defaultfs=$(${ambari_config_get} core-site | awk -F'"' '$2 == "fs.defaultFS" {print $4}' | head -1)
realm=$(${ambari_config_get} kerberos-env | awk -F'"' '$2 == "realm" {print $4}' | head -1)

if [ ! -f /etc/security/keytabs/hdfs.headless.keytab ]; then
  echo
else
  sudo sudo -u hdfs kinit -kt /etc/security/keytabs/hdfs.headless.keytab hdfs-${ambari_cluster}@${realm}
fi
sudo sudo -u hdfs hadoop fs -mkdir -p /ranger/audit/yarn
sudo sudo -u hdfs hadoop fs -chown yarn /ranger/audit/yarn

## Ranger YARN Plugin
${ambari_config_set} ranger-yarn-audit xasecure.audit.destination.db true
${ambari_config_set} ranger-yarn-audit xasecure.audit.destination.hdfs true
${ambari_config_set} ranger-yarn-audit xasecure.audit.destination.solr false
${ambari_config_set} ranger-yarn-audit xasecure.audit.destination.hdfs.dir "${defaultfs}/ranger/audit"
${ambari_config_set} ranger-yarn-audit xasecure.audit.provider.summary.enabled true
${ambari_config_set} ranger-yarn-audit xasecure.audit.is.enabled true
${ambari_config_set} ranger-yarn-plugin-properties common.name.for.certificate " "
${ambari_config_set} ranger-yarn-plugin-properties hadoop.rpc.protection " "
if [ -z "${realm}" ]; then
  echo
else
  ${ambari_config_set} ranger-yarn-plugin-properties REPOSITORY_CONFIG_USERNAME "rangeradmin@${realm}"
  ${ambari_config_set} ranger-yarn-plugin-properties REPOSITORY_CONFIG_PASSWORD "${mypass}"
  ${ambari_config_set} ranger-yarn-plugin-properties policy_user "rangeradmin"
fi
${ambari_config_set} yarn-site yarn.acl.enable true
${ambari_config_set} yarn-site yarn.authorization-provider org.apache.ranger.authorization.yarn.authorizer.RangerYarnAuthorizer
${ambari_config_set} ranger-yarn-plugin-properties ranger-yarn-plugin-enabled Yes

# ranger-yarn-security ranger.add-yarn-authorization false

