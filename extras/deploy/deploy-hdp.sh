#!/usr/bin/env bash

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
source ${__dir}/../ambari_functions.sh

## get mysql community on el/centos7
el_version=$(sed 's/^.\+ release \([.0-9]\+\).*/\1/' /etc/redhat-release | cut -d. -f1)
case ${el_version} in
  "6")
    true
  ;;
  "7")
    sudo rpm -Uvh http://dev.mysql.com/get/mysql-community-release-el7-5.noarch.rpm
  ;;
esac

sudo yum makecache
sudo yum -y -q install git epel-release ntpd
sudo yum -y -q install jq python-argparse python-configobj

sudo usermod -a -G users ${USER}

sudo java_version=8 install_ambari_server=true ${__dir}/../ambari-bootstrap.sh

${__dir}/../providers/google/public-hostname.sh
sudo service ambari-agent restart
sleep 15

cd ${__dir}/../deploy/
cat << EOF > configuration-custom.json
{
  "configurations" : {
      "hdfs-site": {
        "dfs.replication": "1"
      }
  }
}
EOF

#export ambari_services=${ambari_services:-KNOX YARN ZOOKEEPER TEZ PIG SLIDER MAPREDUCE2 HIVE HDFS}
export ambari_services=${ambari_services}
export cluster_name=$(hostname -s)
export host_count=skip
./deploy-recommended-cluster.bash
source ../extras/ambari_functions.sh
ambari-configs
ambari_wait_request_complete 1
cd

sleep 30

