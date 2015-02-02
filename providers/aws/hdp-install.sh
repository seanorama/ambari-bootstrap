#!/usr/bin/env bash
#
# HDP 2.2 install using Ambari & Cloudformation
#
# Usage: ./install-hdp.sh
#
# Options:
#   ambari_host=TheHostName cluster_name=CloudFormationStackName ./hdp-install.sh
#
# Defaults:
#   ambari_host=localhost
#   cluster_name=hdp-simple
#
# Requirements:
#  - bash, aws-cli, jq, curl, sed
#
#################################

set -o errexit
set -o nounset
set -o pipefail

if [ -z ${instance_id+x} ] && [ -z ${region}+x ]; then
    if curl -sSL -m 5 http://169.254.169.254/latest/meta-data -o /dev/null ; then
        on_aws=true
    else
        echo "You must set an instance_id & region within the cloudformation stack"
        exit 1
    fi
else
    echo "Proceeding with instance_id: ${instance_id} and region: ${region}"
fi

if [ "${on_aws}" = true ]; then
    if [[ "$(python -mplatform)" == *"redhat-6"* ]]; then
      hash aws 2>/dev/null || \
          curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip";\
          unzip awscli-bundle.zip;\
          sudo ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
      hash jq 2>/dev/null || sudo yum install -y jq
    fi

    instance_id=$(curl -sSL -m 10 http://169.254.169.254/latest/meta-data/instance-id)
    region=$(curl -sSL -m 10 http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[^0-9]*$//')
fi

hash aws 2>/dev/null || { echo >&2 "I require awscli but it's not installed.  Aborting."; exit 1; }
hash jq 2>/dev/null || { echo >&2 "I require jq but it's not installed.  Aborting."; exit 1; }
hash curl 2>/dev/null || { echo >&2 "I require curl but it's not installed.  Aborting."; exit 1; }

stack_id=$(aws --region ${region} cloudformation describe-stack-resources --physical-resource-id ${instance_id} | jq -r '.StackResources[0].StackId')
stack_name=$(aws --region ${region} cloudformation describe-stack-resources --physical-resource-id ${instance_id} | jq -r '.StackResources[0].StackName')
cluster_name=${stack_name}
ambari_password=${ambari_password:-"admin"}

my_aws_get_hosts() {
    aws --region ${region} ec2 describe-instances --filters "Name=instance-state-name,Values=running" \
        "Name=tag:aws:cloudformation:logical-id,Values=${logical_id}" \
        "Name=tag:aws:cloudformation:stack-name,Values=${stack_name}" \
        "Name=tag:aws:cloudformation:stack-id,Values=${stack_id}" \
        --query "Reservations[].Instances[].[${query}]" --output text
}

nodes_publicnames=$(logical_id="*" query="PublicDnsName" my_aws_get_hosts)
nodes_privatenames=$(logical_id="*" query="PrivateDnsName" my_aws_get_hosts)
ambari_host=$(logical_id="AmbariNode" query="PublicDnsName" my_aws_get_hosts)
ambari_node=$(logical_id="AmbariNode" query="PrivateDnsName" my_aws_get_hosts)
master_nodes=$(logical_id="MasterNode" query="PrivateDnsName" my_aws_get_hosts)
worker_nodes=$(logical_id="WorkerNodes" query="PrivateDnsName" my_aws_get_hosts)
ambari_curl="curl -su admin:${ambari_password} -H X-Requested-By:ambari"
ambari_host=${ambari_host:-"localhost"}
ambari_api="http://${ambari_host}:8080/api/v1"

echo creating blueprint at ./ambari.blueprint
cat > ambari.blueprint <<-'EOF'
{
  "configurations": [
    {
      "nagios-env": {
        "nagios_contact": "admin@localhost"
      }
    },
    {
      "hive-site": {
        "javax.jdo.option.ConnectionUserName": "hive",
        "javax.jdo.option.ConnectionPassword": "hive"
      }
    }
  ],
  "host_groups" : [
    { "name" : "ambari",
      "components" : [
        { "name" : "GANGLIA_MONITOR" },
        { "name" : "HCAT" },
        { "name" : "HDFS_CLIENT" },
        { "name" : "HIVE_CLIENT" },
        { "name" : "MAPREDUCE2_CLIENT" },
        { "name" : "NAGIOS_SERVER" },
        { "name" : "PIG" },
        { "name" : "TEZ_CLIENT" },
        { "name" : "YARN_CLIENT" },
        { "name" : "ZOOKEEPER_CLIENT" }
      ],
      "cardinality" : "1"
    },
    { "name" : "master",
      "components" : [
        { "name" : "APP_TIMELINE_SERVER" },
        { "name" : "GANGLIA_MONITOR" },
        { "name" : "GANGLIA_SERVER" },
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
        { "name" : "HCAT" },
        { "name" : "HDFS_CLIENT" },
        { "name" : "HIVE_CLIENT" },
        { "name" : "JOURNALNODE" },
        { "name" : "MAPREDUCE2_CLIENT" },
        { "name" : "NODEMANAGER" },
        { "name" : "PIG" },
        { "name" : "TEZ_CLIENT" },
        { "name" : "YARN_CLIENT" },
        { "name" : "ZOOKEEPER_CLIENT" }
      ],
      "cardinality" : "1+"
    } 
  ],
  "Blueprints" : { 
    "blueprint_name" : "simple",
    "stack_name" : "HDP",
    "stack_version" : "2.2" 
  }
}
EOF

echo creating cluster host groups blueprint at ./cluster.blueprint
cat > cluster.blueprint << 'EOF'
{
  "blueprint" : "simple",
  "default_password" : "admin",
  "host_groups" : [
    {
      "name" : "ambari",
      "hosts" : [
EOF

for node in ${ambari_node}; do echo '        { "fqdn" : "'$node'" },'; done >> cluster.blueprint 

sed '$ s/,//g' -i cluster.blueprint

cat >> cluster.blueprint << 'EOF'
      ]
    },
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

## Create the blueprint & the clsuter
create_blueprint=$($ambari_curl $ambari_api/blueprints/simple -d @ambari.blueprint)
echo $create_blueprint
create_cluster=$($ambari_curl $ambari_api/clusters/${cluster_name} -d @cluster.blueprint)
echo $create_cluster

echo "Check the cluster creation status with:"
echo "  $ambari_curl $(echo $create_cluster | jq '.href' | tr -d \") | jq '.Requests'"
