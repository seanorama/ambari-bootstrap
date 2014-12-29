wget https://bootstrap.pypa.io/get-pip.py
sudo python get-pip.py 
sudo pip install awscli 
wget http://stedolan.github.io/jq/download/linux64/jq
chmod a+x jq

masterNodes=$(aws ec2 describe-instances --query 'Reservations[].Instances[].[PrivateDnsName,Tags[?Key == `aws:cloudformation:stack-name`] | [0].Value, Tags[?Key == `aws:cloudformation:logical-id`] | [0].Value]' --output text | grep MasterNode | cut -f 1)

workerNodes=$(aws ec2 describe-instances --query 'Reservations[].Instances[].[PrivateDnsName,Tags[?Key == `aws:cloudformation:stack-name`] | [0].Value, Tags[?Key == `aws:cloudformation:logical-id`] | [0].Value]' --output text | grep WorkerNodes | cut -f 1)

cat > ambari.blueprint << 'EOF'
{ 
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
        { "name" : "APP_TIMELINE_SERVER" }
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
        { "name" : "GANGLIA_MONITOR" }  
      ],
      "cardinality" : "1+" 
    } 
  ],
  "Blueprints" : { 
    "blueprint_name" : "multi-node-hdfs-yarn",
    "stack_name" : "HDP",
    "stack_version" : "2.2" 
  }
}
EOF

cat > cluster.blueprint << 'EOF'
{
  "blueprint" : "multi-node-hdfs-yarn",
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

createBlueprint=$(curl -H "X-Requested-By: ambari" -u admin:admin http://localhost:8080/api/v1/blueprints/multi-node-hdfs-yarn1 -d @ambari.blueprint

createCluster=$(curl -H "X-Requested-By: ambari" -u admin:admin http://localhost:8080/api/v1/clusters/SimpleCluster -d @cluster.blueprint)

requestURL=$(echo $createCluster | ./jq '.href')

requestStatus=$(curl -H "X-Requested-By: ambari" -u admin:admin $requestURL)
echo $requestStatus | ./jq '.Requests.request_status'
