#!/usr/bin/env bash

## Install the common unsupported or 3rd party extensions of Ambari and the HDP stack

#hdp_version=`hdp-select status hadoop-client | sed 's/hadoop-client - \([0-9]\.[0-9]\).*/\1/'`
#hdp_version=2.3
hdp_version="$(find /var/lib/ambari-server/resources/stacks/HDP/[0-9]\.[0-9] -mindepth 0 -maxdepth 0 -printf "%f\n" | sort -nr | head -1)"

## zeppelin
git clone https://github.com/hortonworks-gallery/ambari-zeppelin-service.git /var/lib/ambari-server/resources/stacks/HDP/${hdp_version}/services/ZEPPELIN
sed -i.bak '/dependencies for all/a \    "ZEPPELIN_MASTER-START": ["NAMENODE-START", "DATANODE-START"],' /var/lib/ambari-server/resources/stacks/HDP/${hdp_version}/role_command_order.json

## solr
yum -y -q install patch
git clone https://github.com/abajwa-hw/solr-stack.git /var/lib/ambari-server/resources/stacks/HDP/${hdp_version}/services/SOLR
sed -i.bak '/dependencies for all/a \    "SOLR-START" : ["ZOOKEEPER_SERVER-START"],' /var/lib/ambari-server/resources/stacks/HDP/${hdp_version}/role_command_order.json
curl -sSL -O https://gist.githubusercontent.com/seanorama/5992b9f1c9bf594e16e2/raw/d19dba326b9df0ea94d7730beb72aeba4c58478e/add-solrmaster-to-stackadvisor.patch
patch -b /var/lib/ambari-server/resources/stacks/HDP/2.0.6/services/stack_advisor.py < add-solrmaster-to-stackadvisor.patch

## nifi
git clone https://github.com/abajwa-hw/ambari-nifi-service.git   /var/lib/ambari-server/resources/stacks/HDP/${hdp_version}/services/NIFI

## logsearch
git clone https://github.com/abajwa-hw/logsearch-service /var/lib/ambari-server/resources/stacks/HDP/${hdp_version}/services/LOGSEARCH
sed -i.bak '/dependencies for all/a \    "LOGSEARCH_SOLR-START" : ["ZOOKEEPER_SERVER-START"],' /var/lib/ambari-server/resources/stacks/HDP/${hdp_version}/role_command_order.json
sed -i.bak '/dependencies for all/a \    "LOGSEARCH_MASTER-START": ["LOGSEARCH_SOLR-START"],' /var/lib/ambari-server/resources/stacks/HDP/${hdp_version}/role_command_order.json
sed -i.bak '/dependencies for all/a \    "LOGSEARCH_LOGFEEDER-START": ["LOGSEARCH_SOLR-START", "LOGSEARCH_MASTER-START"],' /var/lib/ambari-server/resources/stacks/HDP/${hdp_version}/role_command_order.json

## flink
sudo git clone https://github.com/abajwa-hw/ambari-flink-service.git   /var/lib/ambari-server/resources/stacks/HDP/${hdp_version}/services/FLINK

## jupyter
git clone https://github.com/randerzander/jupyter-service /var/lib/ambari-server/resources/stacks/HDP/${hdp_version}/services/jupyter-service

## R
git clone https://github.com/randerzander/r-service /var/lib/ambari-server/resources/stacks/HDP/${hdp_version}/services/r-service

