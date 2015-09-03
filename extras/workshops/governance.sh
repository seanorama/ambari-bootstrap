#!/usr/bin/bash

## magic, don't touch
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
source ${__dir}/../ambari_functions.sh
ambari-configs

##

#"${__dir}/deploy/prepare-hosts.sh"

#export ambari_services="YARN ZOOKEEPER TEZ OOZIE FLUME PIG SLIDER MAPREDUCE2 HIVE HDFS FALCON ATLAS SQOOP"
#"${__dir}/../deploy/deploy-hdp.sh"

#sudo chkconfig mysqld on; sudo service mysqld start

#source ~/ambari-bootstrap/extras/ambari_functions.sh; ambari-change-pass admin admin BadPass#1
#echo export ambari_pass=BadPass#1 > ~/.ambari.conf; chmod 600 ~/.ambari.conf

#${__dir}/samples/sample-data.sh

exit

${ambari_config_set} webhcat-site webhcat.proxyuser.oozie.groups "*"
${ambari_config_set} webhcat-site webhcat.proxyuser.oozie.hosts "*"
${ambari_config_set} oozie-site   oozie.service.AuthorizationService.security.enabled "false"

#${__dir}/add-trusted-ca.sh

${__dir}/onboarding.sh
#${__dir}/samples/sample-data.sh
${__dir}/configs/proxyusers.sh
proxyusers="oozie falcon" ${__dir}/configs/proxyusers.sh
${__dir}/oozie/replace-mysql-connector.sh
${__dir}/atlas/atlas-hive-enable.sh
config_proxyuser=true ${__dir}/ambari-views/create-views.sh

