#!/usr/bin/env bash
#
# HDP 2.2 install using Ambari & Cloudformation
#
# Current features:
#  - Populates hosts list from AWS
#  - Can be run from any host with access to :8080 on the Ambari Server
#
# Usage: ./install-hdp.sh
#  - assumes Cloudformation stack name of 'hdp-simple'
#    - Override with: cfn_stack=YOURSTACKNAME ./hdp-install.sh
#
# Requirements:
#  - bash, aws-cli, jq, curl, sed
#
#################################

set -o errexit
set -o nounset
set -o pipefail

my_aws_get_hosts() {
    aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" \
        "Name=tag:aws:cloudformation:logical-id,Values=${logical_id}" \
        "Name=tag:aws:cloudformation:stack-name,Values=${cfn_stack}" \
        --query "Reservations[].Instances[].[${query}]" --output text
}

my_aws_prep() {
# install requirements on redhat-6
if [[ "$(python -mplatform)" == *"redhat-6"* ]]; then
  hash aws 2>/dev/null || \
      curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip";\
      unzip awscli-bundle.zip;\
      sudo ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
  hash jq 2>/dev/null || sudo yum install -y jq
fi

# check requirements
hash aws 2>/dev/null || { echo >&2 "I require awscli but it's not installed.  Aborting."; exit 1; }
hash jq 2>/dev/null || { echo >&2 "I require jq but it's not installed.  Aborting."; exit 1; }
hash curl 2>/dev/null || { echo >&2 "I require curl but it's not installed.  Aborting."; exit 1; }

# configure aws: should add a check to see if already configured
aws configure

# populate host list variables
ambari_host=$(logical_id="AmbariNode" query="PublicDnsName" my_aws_get_hosts)
master_nodes=$(logical_id="MasterNode" query="PrivateDnsName" my_aws_get_hosts)
worker_nodes=$(logical_id="WorkerNodes" query="PrivateDnsName" my_aws_get_hosts)
}

### Configuration
cfn_stack=${cfn_stack:-"hdp-simple"}
my_aws_prep
ambari_curl="curl -su admin:admin -H X-Requested-By:ambari"
ambari_host=${ambari_host:-"localhost"}
ambari_api="http://${ambari_host}:8080/api/v1"

echo creating blueprint at ./ambari.blueprint
cat > ambari.blueprint <<-'EOF'
{
  "configurations" : {
      "hive-site" : {
        "javax.jdo.option.ConnectionPassword" : "admin"
      },
      "nagios-env" : {
        "nagios_contact" : "admin@localhost"
      }
  },
  "host_groups" : [
    { "name" : "master",
      "components" : [
        { "name" : "APP_TIMELINE_SERVER" },
        { "name" : "GANGLIA_MONITOR" },
        { "name" : "GANGLIA_SERVER" },
        { "name" : "HCAT" },
        { "name" : "HISTORYSERVER" },
        { "name" : "HIVE_METASTORE" },
        { "name" : "HIVE_SERVER" },
        { "name" : "JOURNALNODE" },
        { "name" : "MYSQL_SERVER" },
        { "name" : "NAMENODE" },
        { "name" : "NODEMANAGER" },
        { "name" : "RESOURCEMANAGER" },
        { "name" : "SECONDARY_NAMENODE" },
        { "name" : "WEBHCAT_SERVER" },
        { "name" : "ZOOKEEPER_SERVER" }
      ],
      "cardinality" : "1"
    },
    { "name" : "slaves",
      "components" : [
        { "name" : "DATANODE" },
        { "name" : "GANGLIA_MONITOR" },
        { "name" : "HDFS_CLIENT" },
        { "name" : "HIVE_CLIENT" },
        { "name" : "JOURNALNODE" },
        { "name" : "MAPREDUCE2_CLIENT" },
        { "name" : "NODEMANAGER" },
        { "name" : "TEZ_CLIENT" },
        { "name" : "YARN_CLIENT" },
        { "name" : "ZOOKEEPER_CLIENT" }
      ],
      "cardinality" : "1+"
    } 
  ],
  "Blueprints" : { 
    "blueprint_name" : "single-master",
    "stack_name" : "HDP",
    "stack_version" : "2.2" 
  }
}
EOF

echo creating cluster host groups blueprint at ./cluster.blueprint
cat > cluster.blueprint << 'EOF'
{
  "blueprint" : "single-master",
  "host_groups" :[
    {
      "name" : "master", 
      "hosts" : [ 
EOF

for node in ${master_nodes}; do echo '        { "fqdn" : "'$node'" },'; done >> cluster.blueprint 

sed '$ s/,//g' -i cluster.blueprint

cat >> cluster.blueprint << 'EOF'
      ]
    },
    {
      "name" : "slaves", 
      "hosts" : [
EOF

for node in $worker_nodes; do echo '        { "fqdn" : "'$node'" },'; done >> cluster.blueprint 

sed '$ s/,//g' -i cluster.blueprint

cat >> cluster.blueprint << 'EOF'
      ]
    }
  ]
}
EOF

# now to start the show
create_blueprint=$($ambari_curl $ambari_api/blueprints/single-master -d @ambari.blueprint)
echo $create_blueprint
create_cluster=$($ambari_curl $ambari_api/clusters/simple -d @cluster.blueprint)
echo $create_cluster

echo "Check the cluster creation status with:"
echo "  $ambari_curl $(echo $create_cluster | jq '.href' | tr -d \") | jq '.Requests'"
