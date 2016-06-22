#!/usr/bin/env bash

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
source ${__dir}/../ambari_functions.sh

custom_repos="${custom_repos:-false}"

sudo yum makecache
sudo yum -y -q install git epel-release ntpd
sudo yum -y -q install jq python-argparse python-configobj

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

sudo usermod -a -G users ${USER}

if [ "${custom_repos}" = true  ]; then
    ambari_repo=http://storage.googleapis.com/hdp-repo-mirror/ambari/centos7/ambari.repo
fi
sudo ambari_repo=${ambari_repo} java_provider=open java_version=8 install_ambari_server=true ${__dir}/../ambari-bootstrap.sh

if [ "${custom_repos}" = true  ]; then
    ${__dir}/../providers/google/public-hostname.sh
    sudo service ambari-agent restart
    sleep 15
fi

ambari_configs

## Update to use repos on Google Cloud
if [ "${custom_repos}" = true  ]; then

read -r -d '' body <<EOF
{ "Repositories" : { "base_url" : "http://storage.googleapis.com/hdp-repo-mirror/hdp/centos7/HDP-2.3" } }
EOF
echo "${body}" | ${ambari_curl}/stacks/HDP/versions/2.3/operating_systems/redhat7/repositories/HDP-2.3 -X PUT -d @-

read -r -d '' body <<EOF
{ "Repositories" : { "base_url" : "http://storage.googleapis.com/hdp-repo-mirror/hdp/centos7/HDP-UTILS-1.1.0.20" } }
EOF
echo "${body}" | ${ambari_curl}/stacks/HDP/versions/2.3/operating_systems/redhat7/repositories/HDP-UTILS-1.1.0.20 -X PUT -d @-

fi

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
export cluster_name="${cluster_name:-$(hostname -s)}"
export host_count=skip
./deploy-recommended-cluster.bash
