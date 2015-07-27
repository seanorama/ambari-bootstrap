#!/usr/bin/env bash

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__root="$(cd "$(dirname "${__dir}")" && pwd)" # <-- change this
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"

source ${__dir}/../ambari_functions.sh

ambari-configs

webhdfs=$(${ambari_config_get} hdfs-site | awk -F'"' '$2 == "dfs.namenode.http-address" {print $4}' | head -1)
defaultfs=$(${ambari_config_get} core-site | awk -F'"' '$2 == "fs.defaultFS" {print $4}' | head -1)

## Ranger HDFS Plugin
${ambari_config_set} ranger-hdfs-audit xasecure.audit.destination.db true
${ambari_config_set} ranger-hdfs-audit xasecure.audit.destination.hdfs.dir "${defaultfs}/ranger/audit"
${ambari_config_set} ranger-hdfs-audit xasecure.audit.is.enabled true
${ambari_config_set} ranger-hdfs-audit xasecure.audit.provider.summary.enabled true
${ambari_config_set} ranger-hdfs-plugin-properties REPOSITORY_CONFIG_USERNAME rangeradmin
${ambari_config_set} ranger-hdfs-plugin-properties REPOSITORY_CONFIG_PASSWORD BadPass#1
${ambari_config_set} ranger-hdfs-plugin-properties common.name.for.certificate " "
${ambari_config_set} core-site hadoop.security.authorization true
${ambari_config_set} hdfs-site dfs.namenode.inode.attributes.provider.class org.apache.ranger.authorization.hadoop.RangerHdfsAuthorizer
${ambari_config_set} ranger-hdfs-plugin-properties ranger-hdfs-plugin-enabled yes

### (optional) For demoing only to get hdfs audits quickly
${ambari_config_set} ranger-hdfs-audit xasecure.audit.hdfs.async.max.flush.interval.ms 30000
${ambari_config_set} ranger-hdfs-audit xasecure.audit.hdfs.config.destination.flush.interval.seconds 60
${ambari_config_set} ranger-hdfs-audit xasecure.audit.hdfs.config.destination.open.retry.interval.seconds 60
${ambari_config_set} ranger-hdfs-audit xasecure.audit.hdfs.config.destination.rollover.interval.seconds 30
${ambari_config_set} ranger-hdfs-audit xasecure.audit.hdfs.config.local.buffer.flush.interval.seconds 60
${ambari_config_set} ranger-hdfs-audit xasecure.audit.hdfs.config.local.buffer.rollover.interval.seconds 60

