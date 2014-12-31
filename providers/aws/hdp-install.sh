#!/usr/bin/env bash

set -e

# Configuration
# =============

AMBARI_HOST=${AMBARI_HOST:-localhost}
# replace with name of your CloudFormation Stack
STACK=hdp-simple


AMBARI_CURL="curl -su admin:admin -H X-Requested-By:ambari"
AMBARI_API="http://${AMBARI_HOST}:8080/api/v1"


# Requirements
# ============
curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
unzip awscli-bundle.zip
sudo ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
sudo yum install jq

aws configure

# replace with the name of your deployed stack

ambariNode=$(aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=tag:aws:cloudformation:logical-id,Values=AmbariNode" "Name=tag:aws:cloudformation:stack-name,Values=$STACK" --query 'Reservations[].Instances[].[PublicIpAddress]' --output text)
echo Ambari is available at: http://$ambariNode:8080/

masterNodes=$(aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=tag:aws:cloudformation:logical-id,Values=MasterNode" "Name=tag:aws:cloudformation:stack-name,Values=$STACK" --query 'Reservations[].Instances[].[PrivateDnsName]' --output text)
workerNodes=$(aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" "Name=tag:aws:cloudformation:logical-id,Values=WorkerNodes" "Name=tag:aws:cloudformation:stack-name,Values=$STACK" --query 'Reservations[].Instances[].[PrivateDnsName]' --output text)

nodes=""; for node in $workerNodes $masterNodes; do nodes=$(printf '%s"%s"' "$nodes", "$node"); done; nodes="[ ${nodes#,} ]"

echo creating blueprint at ./ambari.blueprint
cat > ambari.blueprint << 'EOF'
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

for node in $masterNodes; do echo '        { "fqdn" : "'$node'" },'; done >> cluster.blueprint 

sed '$ s/,//g' -i cluster.blueprint

cat >> cluster.blueprint << 'EOF'
      ]
    },
    {
      "name" : "slaves", 
      "hosts" : [
EOF

for node in $workerNodes; do echo '        { "fqdn" : "'$node'" },'; done >> cluster.blueprint 

sed '$ s/,//g' -i cluster.blueprint

cat >> cluster.blueprint << 'EOF'
      ]
    }
  ]
}
EOF

createBlueprint=$($AMBARI_CURL $AMBARI_API/blueprints/single-master -d @ambari.blueprint)

createCluster=$($AMBARI_CURL $AMBARI_API/clusters/simple -d @cluster.blueprint)

requestURL=$(echo $createCluster | jq '.href' | tr -d \")

watch -n 10 "$AMBARI_CURL $requestURL | jq '.Requests'"
