#!/usr/bin/env bash

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__root="$(cd "$(dirname "${__dir}")" && pwd)" # <-- change this
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"

source ${__dir}/../ambari_functions.sh

ambari-configs

defaultfs=$(${ambari_config_get} core-site | awk -F'"' '$2 == "fs.defaultFS" {print $4}' | head -1)

sudo sudo -u hdfs hadoop fs -mkdir -p /ranger/audit/hbaseMaster
sudo sudo -u hdfs hadoop fs -mkdir -p /ranger/audit/hbaseRegional
sudo sudo -u hdfs hadoop fs -chown hbase /ranger/audit/hbaseRegional
sudo sudo -u hdfs hadoop fs -chown hbase /ranger/audit/hbaseMaster

## Ranger HBase Plugin
${ambari_config_set} hbase-site hbase.security.authorization true
${ambari_config_set} hbase-site hbase.coprocessor.region.classes '{{hbase_coprocessor_region_classes}}'
${ambari_config_set} hbase-site hbase.coprocessor.master.classes '{{hbase_coprocessor_master_classes}}'

${ambari_config_set} ranger-hbase-audit xasecure.audit.destination.db true
${ambari_config_set} ranger-hbase-audit xasecure.audit.destination.hdfs.dir "${defaultfs}/ranger/audit"
${ambari_config_set} ranger-hbase-audit xasecure.audit.is.enabled true
${ambari_config_set} ranger-hbase-audit xasecure.audit.provider.summary.enabled true
${ambari_config_set} ranger-hbase-plugin-properties common.name.for.certificate " "

${ambari_config_set} ranger-hbase-plugin-properties ranger-hbase-plugin-enabled yes
