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

## TODO: Check when this will be fixed.
sudo ln -s /usr/hdp/current/hadoop-client/conf/core-site.xml /usr/hdp/current/ranger-kms/conf/

#sudo keytool -import -trustcacerts -alias root \
#  -noprompt -storepass changeit \
#  -file /etc/pki/ca-trust/source/anchors/activedirectory.pem \
#  -keystore /usr/hdp/current/ranger-kms/conf/ranger-plugin-keystore.jks

#sudo sudo -u hdfs kinit -kt /etc/security/keytabs/hdfs.headless.keytab hdfs-$(hostname -s)
sudo sudo -u hdfs hadoop fs -mkdir /ranger/audit/kms
sudo sudo -u hdfs hadoop fs -chown kms /ranger/audit/kms

## Ranger KMS
#${ambari_config_set} kms-properties REPOSITORY_CONFIG_PASSWORD "BadPass#1"
#${ambari_config_set} kms-properties REPOSITORY_CONFIG_USERNAME "keyadmin@HORTONWORKS.COM"
${ambari_config_set} kms-properties common.name.for.certificate " "

${ambari_config_set} kms-site hadoop.kms.proxyuser.keyadmin.hosts "*"
${ambari_config_set} kms-site hadoop.kms.proxyuser.keyadmin.groups "users, hadoop-users"
${ambari_config_set} kms-site hadoop.kms.proxyuser.rangeradmin.hosts "*"
${ambari_config_set} kms-site hadoop.kms.proxyuser.rangeradmin.groups "users, hadoop-users"

${ambari_config_set} ranger-kms-audit xasecure.audit.destination.db true
${ambari_config_set} ranger-kms-audit xasecure.audit.destination.hdfs.dir "${defaultfs}/ranger/audit"
${ambari_config_set} ranger-kms-audit xasecure.audit.destination.solr flase
${ambari_config_set} ranger-kms-audit xasecure.audit.provider.summary.enabled true
${ambari_config_set} ranger-kms-audit xasecure.audit.is.enabled true
