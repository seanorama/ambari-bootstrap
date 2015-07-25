#!/usr/bin/env bash

## install Amabari Views with the JSON files in this directory
##  this only works on non-kerberized clusters where all servers are on the same node

source ../ambari_functions.sh

ambari-configs

## granting root super user rights
#${ambari_config_set} core-site hadoop.proxyuser.root.groups "users"
#${ambari_config_set} core-site hadoop.proxyuser.root.hosts "$(hostname -f)"

webhdfs=$(${ambari_config_get} hdfs-site | awk -F'"' '$2 == "dfs.namenode.http-address" {print $4}' | head -1)

## install views
views="hive files pig"
for view in ${views}; do
  sed -e "s,webhdfs://.*:50070,webhdfs://${webhdfs}," ${view}.json > /tmp/ambari-view-${view}.json
  ${ambari_curl}/views/${view^^}/versions/1.0.0/instances/${view~} \
    -v -X POST -d @/tmp/ambari-view-${view}.json
done
