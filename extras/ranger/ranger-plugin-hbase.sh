#!/usr/bin/env bash

mypass=${mypass:-BadPass#1}

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
sudo sudo -u hdfs hadoop fs -mkdir -p /ranger/audit/hbaseMaster
sudo sudo -u hdfs hadoop fs -mkdir -p /ranger/audit/hbaseRegional
sudo sudo -u hdfs hadoop fs -chown hbase /ranger/audit/hbaseRegional
sudo sudo -u hdfs hadoop fs -chown hbase /ranger/audit/hbaseMaster

## Ranger HBase Plugin
${ambari_config_set} ranger-hbase-audit xasecure.audit.destination.db true
${ambari_config_set} ranger-hbase-audit xasecure.audit.destination.hdfs true
${ambari_config_set} ranger-hbase-audit xasecure.audit.destination.solr false
${ambari_config_set} ranger-hbase-audit xasecure.audit.destination.hdfs.dir "${defaultfs}/ranger/audit"
${ambari_config_set} ranger-hbase-audit xasecure.audit.provider.summary.enabled true
${ambari_config_set} ranger-hbase-audit xasecure.audit.is.enabled true
${ambari_config_set} ranger-hbase-plugin-properties common.name.for.certificate " "
${ambari_config_set} ranger-hbase-plugin-properties hadoop.rpc.protection " "
if [ -z "${realm}" ]; then
  echo
else
  ${ambari_config_set} ranger-hbase-plugin-properties REPOSITORY_CONFIG_USERNAME "rangeradmin@${realm}"
  ${ambari_config_set} ranger-hbase-plugin-properties REPOSITORY_CONFIG_PASSWORD "${mypass}"
  ${ambari_config_set} ranger-hbase-plugin-properties policy_user "rangeradmin"
fi

${ambari_config_set} hbase-site hbase.coprocessor.region.classes '{{hbase_coprocessor_region_classes}},org.apache.ranger.authorization.hbase.RangerAuthorizationCoprocessor'
${ambari_config_set} hbase-site hbase.coprocessor.master.classes '{{hbase_coprocessor_master_classes}},org.apache.ranger.authorization.hbase.RangerAuthorizationCoprocessor'
${ambari_config_set} hbase-site hbase.security.authorization true
${ambari_config_set} ranger-hbase-plugin-properties ranger-hbase-plugin-enabled Yes
