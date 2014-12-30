wget https://bootstrap.pypa.io/get-pip.py
sudo python get-pip.py
sudo pip install awscli
wget http://stedolan.github.io/jq/download/linux64/jq
chmod a+x jq

ambariPublicIP=$(aws ec2 describe-instances --query 'Reservations[].Instances[].[PublicIpAddress,Tags[?Key == `aws:cloudformation:stack-name`] | [0].Value, Tags[?Key == `aws:cloudformation:logical-id`] | [0].Value]' --output text | grep AmbariNode | cut -f 1)
echo Ambari is available at: http://$ambariPublicIP:8080/

masterNodes=$(aws ec2 describe-instances --query 'Reservations[].Instances[].[PrivateDnsName,Tags[?Key == `aws:cloudformation:stack-name`] | [0].Value, Tags[?Key == `aws:cloudformation:logical-id`] | [0].Value]' --output text | grep MasterNode | cut -f 1)

workerNodes=$(aws ec2 describe-instances --query 'Reservations[].Instances[].[PrivateDnsName,Tags[?Key == `aws:cloudformation:stack-name`] | [0].Value, Tags[?Key == `aws:cloudformation:logical-id`] | [0].Value]' --output text | grep WorkerNodes | cut -f 1)

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

AMBARI_CURL='curl -su admin:admin -H X-Requested-By:ambari'
AMBARI_API='http://localhost:8080/api/v1'

createBlueprint=$($AMBARI_CURL $AMBARI_API/blueprints/single-master -d @ambari.blueprint)

createCluster=$($AMBARI_CURL $AMBARI_API/clusters/SimpleCluster -d @cluster.blueprint)

requestURL=$(echo $createCluster | ./jq '.href')

requestStatus=$($AMBARI_CURL $requestURL)
echo $requestStatus | ./jq '.Requests.request_status'
