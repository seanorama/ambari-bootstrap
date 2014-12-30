wget https://bootstrap.pypa.io/get-pip.py
sudo python get-pip.py
sudo pip install awscli
wget http://stedolan.github.io/jq/download/linux64/jq
chmod a+x jq

aws configure

# replace with the name of your deployed stack
stackName=hdp2

ambariNode=$(aws ec2 describe-instances --filters "Name=tag:aws:cloudformation:logical-id,Values=AmbariNode" "Name=tag:aws:cloudformation:stack-name,Values=$stackName" --query 'Reservations[].Instances[].[PublicIpAddress]' --output text)
echo Ambari is available at: http://$ambariNode:8080/

masterNodes=$(aws ec2 describe-instances --filters "Name=tag:aws:cloudformation:logical-id,Values=MasterNode" "Name=tag:aws:cloudformation:stack-name,Values=$stackName" --query 'Reservations[].Instances[].[PrivateDnsName]' --output text)
workerNodes=$(aws ec2 describe-instances --filters "Name=tag:aws:cloudformation:logical-id,Values=WorkerNodes" "Name=tag:aws:cloudformation:stack-name,Values=$stackName" --query 'Reservations[].Instances[].[PrivateDnsName]' --output text)

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
        { "name" : "NAMENODE" },
        { "name" : "SECONDARY_NAMENODE" },
        { "name" : "RESOURCEMANAGER" },
        { "name" : "HISTORYSERVER" },
        { "name" : "ZOOKEEPER_SERVER" },
        { "name" : "GANGLIA_SERVER" },
        { "name" : "GANGLIA_MONITOR" },
        { "name" : "APP_TIMELINE_SERVER" },
        { "name" : "HIVE_METASTORE" },
        { "name" : "HIVE_SERVER" },
        { "name" : "WEBHCAT_SERVER" },
        { "name" : "MYSQL_SERVER" }
      ],
      "cardinality" : "1"
    },
    { "name" : "slaves",
      "components" : [
        { "name" : "DATANODE" },
        { "name" : "HDFS_CLIENT" },
        { "name" : "NODEMANAGER" },
        { "name" : "YARN_CLIENT" },
        { "name" : "MAPREDUCE2_CLIENT" },
        { "name" : "ZOOKEEPER_CLIENT" },
        { "name" : "GANGLIA_MONITOR" },
        { "name" : "TEZ_CLIENT" },
        { "name" : "HIVE_CLIENT" }
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

AMBARI_CURL="curl -su admin:admin -H X-Requested-By:ambari"
AMBARI_API="http://localhost:8080/api/v1"

createBlueprint=$($AMBARI_CURL $AMBARI_API/blueprints/single-master -d @ambari.blueprint)

createCluster=$($AMBARI_CURL $AMBARI_API/clusters/SimpleCluster -d @cluster.blueprint)

requestURL=$(echo $createCluster | ./jq '.href' | tr -d \")

requestStatus=$($AMBARI_CURL $requestURL)
echo $requestStatus | ./jq '.Requests.request_status'
