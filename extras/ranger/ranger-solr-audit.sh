#!/usr/bin/env bash

mypass=${mypass:-BadPass#1}

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__root="$(cd "$(dirname "${__dir}")" && pwd)" # <-- change this
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"

source ${__dir}/../ambari_functions.sh
ambari_configs

${ambari_config_set} ranger-admin-site ranger.audit.source.type solr
${ambari_config_set} ranger-admin-site ranger.audit.solr.urls "http://localhost:8983/solr/ranger_audits"
${ambari_config_set} ranger-hdfs-audit xasecure.audit.destination.solr true
#${ambari_config_set} ranger-hdfs-audit xasecure.audit.destination.solr.zookeepers $(hostname -f):2181
${ambari_config_set} ranger-hdfs-audit xasecure.audit.destination.solr true
#${ambari_config_set} ranger-hive-audit xasecure.audit.destination.solr.zookeepers $(hostname -f):2181
${ambari_config_set} ranger-hive-audit xasecure.audit.destination.solr true
#${ambari_config_set} ranger-yarn-audit xasecure.audit.destination.solr.zookeepers $(hostname -f):2181
${ambari_config_set} ranger-yarn-audit xasecure.audit.destination.solr true
#${ambari_config_set} ranger-hbase-audit xasecure.audit.destination.solr.zookeepers $(hostname -f):2181
${ambari_config_set} ranger-hbase-audit xasecure.audit.destination.solr true
#${ambari_config_set} ranger-kms-audit xasecure.audit.destination.solr.zookeepers $(hostname -f):2181
${ambari_config_set} ranger-kms-audit xasecure.audit.destination.solr true
