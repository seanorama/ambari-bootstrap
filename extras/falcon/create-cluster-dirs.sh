#!/usr/bin/env bash

## creates the dirs required for adding a Falcon cluster

clusterName="${clusterName:-clusterName}"

########################################################################

## Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
source ${__dir}/../ambari_functions.sh
ambari_configs

realm=$(${ambari_config_get} kerberos-env | awk -F'"' '$2 == "realm" {print $4}' | head -1)

if [ ! -f /etc/security/keytabs/hdfs.headless.keytab ]; then true
else
  sudo sudo -u hdfs kinit -kt /etc/security/keytabs/hdfs.headless.keytab hdfs-${ambari_cluster}@${realm}
fi

sudo sudo -u hdfs hadoop fs -mkdir -p /apps/falcon/${clusterName}/staging /apps/falcon/${clusterName}/working
sudo sudo -u hdfs hadoop fs -chmod    777 /apps/falcon/${clusterName}/staging
sudo sudo -u hdfs hadoop fs -chmod    755 /apps/falcon/${clusterName}/working
sudo sudo -u hdfs hadoop fs -chown -R falcon:hadoop /apps/falcon/${clusterName}

