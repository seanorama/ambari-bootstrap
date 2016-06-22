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
sudo sudo -u hdfs hadoop fs -mkdir -p /ranger/audit/hiveServer2
sudo sudo -u hdfs hadoop fs -chown hive /ranger/audit/hiveServer2

## Ranger Hive Plugin
${ambari_config_set} ranger-hive-audit xasecure.audit.destination.db true
${ambari_config_set} ranger-hive-audit xasecure.audit.destination.hdfs true
${ambari_config_set} ranger-hive-audit xasecure.audit.destination.solr false
${ambari_config_set} ranger-hive-audit xasecure.audit.destination.hdfs.dir "${defaultfs}/ranger/audit"
${ambari_config_set} ranger-hive-audit xasecure.audit.is.enabled true
${ambari_config_set} ranger-hive-audit xasecure.audit.provider.summary.enabled true
if [ -z "${realm}" ]; then
  echo
else
  ${ambari_config_set} ranger-hive-plugin-properties REPOSITORY_CONFIG_USERNAME "rangeradmin@${realm}"
  ${ambari_config_set} ranger-hive-plugin-properties REPOSITORY_CONFIG_PASSWORD "${mypass}"
  ${ambari_config_set} ranger-hive-plugin-properties policy_user "rangeradmin"
fi
${ambari_config_set} ranger-hive-plugin-properties common.name.for.certificate " "
${ambari_config_set} ranger-hive-plugin-properties hadoop.rpc.protection " "
${ambari_config_set} ranger-hive-plugin-properties ranger-hive-plugin-enabled Yes

${ambari_config_set} hiveserver2-site hive.security.authorization.manager "org.apache.ranger.authorization.hive.authorizer.RangerHiveAuthorizerFactory"
${ambari_config_set} hiveserver2-site hive.security.authenticator.manager "org.apache.hadoop.hive.ql.security.SessionStateUserAuthenticator"
${ambari_config_set} hiveserver2-site hive.security.authorization.enabled true

${ambari_config_set} hive-site hive.security.authorization.manager "org.apache.hadoop.hive.ql.security.authorization.plugin.sqlstd.SQLStdConfOnlyAuthorizerFactory"
#${ambari_config_set} hive-site hive.security.metastore.authenticator.manager "org.apache.hadoop.hive.ql.security.HadoopDefaultMetastoreAuthenticator"
#${ambari_config_set} hive-site hive.security.metastore.authorization.manager "org.apache.hadoop.hive.ql.security.authorization.StorageBasedAuthorizationProvider"
${ambari_config_set} hive-site hive.security.authorization.enabled true
${ambari_config_set} hive-site hive.server2.enable.doAs false
hive_conf_restricted_list=$(${ambari_config_get} hive-site | awk -F'"' '$2 == "hive.conf.restricted.list" {print $4}' | head -1)
${ambari_config_set} hive-site hive.conf.restricted.list "${hive_conf_restricted_list},hive.security.authorization.enabled"

${ambari_config_set} hive-env hive_security_authorization Ranger
