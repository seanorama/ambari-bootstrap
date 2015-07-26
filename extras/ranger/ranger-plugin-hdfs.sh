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
echo ${ambari_config_set} ranger-hdfs-audit xasecure.audit.destination.db true
echo ${ambari_config_set} ranger-hdfs-audit xasecure.audit.destination.hdfs.dir "${defaultfs}/ranger/audit"
echo ${ambari_config_set} ranger-hdfs-audit xasecure.audit.is.enabled true
echo ${ambari_config_set} ranger-hdfs-audit xasecure.audit.provider.summary.enabled true
echo ${ambari_config_set} ranger-hdfs-plugin-properties common.name.for.certificate " "
echo ${ambari_config_set} core-site hadoop.security.authorization true
echo ${ambari_config_set} hdfs-site dfs.namenode.inode.attributes.provider.class org.apache.ranger.authorization.hadoop.RangerHdfsAuthorizer
echo ${ambari_config_set} ranger-hdfs-plugin-properties ranger-hdfs-plugin-enabled yes
