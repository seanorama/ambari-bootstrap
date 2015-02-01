from troposphere import Base64, Select, FindInMap, GetAtt, GetAZs, Join, Output
from troposphere import Template, Parameter, Ref, Condition, Equals, And, Or, Not, If
from troposphere import Parameter, Ref, Tags, Template
from troposphere.cloudformation import Init
from troposphere.cloudfront import Distribution, DistributionConfig
from troposphere.cloudfront import Origin, DefaultCacheBehavior
from troposphere.ec2 import PortRange
from troposphere.ec2 import Subnet
from troposphere.iam import Policy, PolicyType
from troposphere.iam import InstanceProfile
from troposphere.iam import Role
from troposphere.autoscaling import LaunchConfiguration
from troposphere.ec2 import Instance, NetworkInterfaceProperty
from troposphere.ec2 import RouteTable
from troposphere.ec2 import SecurityGroup
from troposphere.ec2 import Route
from troposphere.ec2 import BlockDeviceMapping, EBSBlockDevice
from troposphere.autoscaling import AutoScalingGroup
from troposphere.ec2 import SubnetRouteTableAssociation
from troposphere.ec2 import InternetGateway
from troposphere.ec2 import VPC
from troposphere.ec2 import VPCGatewayAttachment


def template():
    t = Template()
    for p in parameters.values():
        t.add_parameter(p)
    for k in conditions:
        t.add_condition(k, conditions[k])
    for r in resources.values():
        t.add_resource(r)
    return t

t = Template()
print(template().to_json())

t.add_version("2010-09-09")

t.add_description("""\
CloudFormation template to Deploy Hortonworks Data Platform on VPC with a public subnet""")
AmbariInstanceType = t.add_parameter(Parameter(
    "AmbariInstanceType",
    Default="m3.large",
    ConstraintDescription="Must be a valid EC2 instance type.",
    Type="String",
    Description="Instance type for Ambari node",
))

WorkerInstanceCount = t.add_parameter(Parameter(
    "WorkerInstanceCount",
    Default="2",
    Type="Number",
    Description="Number of Worker instances",
    MaxValue="99",
    MinValue="1",
))

WorkerInstanceType = t.add_parameter(Parameter(
    "WorkerInstanceType",
    Default="i2.4xlarge",
    ConstraintDescription="Must be a valid EC2 instance type.",
    Type="String",
    Description="Instance type for worker node",
))

SSHLocation = t.add_parameter(Parameter(
    "SSHLocation",
    ConstraintDescription="Must be a valid CIDR range.",
    Description="SSH access for Ambari Node",
    Default="0.0.0.0/0",
    MinLength="9",
    AllowedPattern="(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})/(\\d{1,2})",
    MaxLength="18",
    Type="String",
))

MasterInstanceType = t.add_parameter(Parameter(
    "MasterInstanceType",
    Default="c3.4xlarge",
    ConstraintDescription="Must be a valid EC2 instance type.",
    Type="String",
    Description="Instance type for master node",
))

KeyName = t.add_parameter(Parameter(
    "KeyName",
    ConstraintDescription="Can contain only ASCII characters.",
    Type="AWS::EC2::KeyPair::KeyName",
    Description="Name of an existing EC2 KeyPair to enable SSH access to the instance",
))

MasterUseEBS = t.add_parameter(Parameter(
    "MasterUseEBS",
    Default="no",
    ConstraintDescription="Must be yes or no only.",
    Type="String",
    Description="Use EBS Volumes for the Master Node",
    AllowedValues=["yes", "no"],
))

WorkerUseEBS = t.add_parameter(Parameter(
    "WorkerUseEBS",
    Default="no",
    ConstraintDescription="Must be yes or no only.",
    Type="String",
    Description="Use EBS Volumes for the Worker Node",
    AllowedValues=["yes", "no"],
))

conditions = {
    "MasterUseEBSBool": Equals(Ref("MasterUseEBS"),"yes"),
    "WorkerUseEBSBool": Equals(Ref("WorkerUseEBS"),"yes"),
}

for k in conditions:
    t.add_condition(k, conditions[k])


t.add_mapping("SubnetConfig",
{'Public': {'CIDR': '10.0.0.0/24'}, 'VPC': {'CIDR': '10.0.0.0/16'}}
)

t.add_mapping("CENTOS6",
{'ap-northeast-1': {'AMI': 'ami-25436924'},
 'ap-southeast-1': {'AMI': 'ami-0aaf8858'},
 'ap-southeast-2': {'AMI': 'ami-ef5133d5'},
 'eu-west-1': {'AMI': 'ami-4ac6653d'},
 'sa-east-1': {'AMI': 'ami-9b962386'},
 'us-east-1': {'AMI': 'ami-bc8131d4'},
 'us-west-1': {'AMI': 'ami-33c1ca76'},
 'us-west-2': {'AMI': 'ami-a9de9c99'}}
)

t.add_mapping("RHEL66",
{'ap-northeast-1': {'AMI': 'ami-a15666a0'},
 'ap-southeast-1': {'AMI': 'ami-3813326a'},
 'ap-southeast-2': {'AMI': 'ami-55e38e6f'},
 'eu-west-1': {'AMI': 'ami-9cfd53eb'},
 'sa-east-1': {'AMI': 'ami-995ce884'},
 'us-east-1': {'AMI': 'ami-aed06ac6'},
 'us-west-1': {'AMI': 'ami-69ccd92c'},
 'us-west-2': {'AMI': 'ami-5fbcf36f'}}
)

PublicSubnet = t.add_resource(Subnet(
    "PublicSubnet",
    VpcId=Ref("VPC"),
    CidrBlock=FindInMap("SubnetConfig", "Public", "CIDR"),
))

CFNRolePolicies = t.add_resource(PolicyType(
    "CFNRolePolicies",
    PolicyName="CFNaccess",
    PolicyDocument={ "Statement": [{ "Action": "cloudformation:Describe*", "Resource": "*", "Effect": "Allow" }] },
    Roles=[Ref("AmbariAccessRole")],
))

AmbariInstanceProfile = t.add_resource(InstanceProfile(
    "AmbariInstanceProfile",
    Path="/",
    Roles=[Ref("AmbariAccessRole")],
))

NodeAccessRole = t.add_resource(Role(
    "NodeAccessRole",
    Path="/",
    AssumeRolePolicyDocument={ "Statement": [{ "Action": ["sts:AssumeRole"], "Effect": "Allow", "Principal": { "Service": ["ec2.amazonaws.com"] } }] },
))

## Functions to generate blockdevicemappings
##   count: the number of devices to map
##   devicenamebase: "/dev/sd" or "/dev/xvd"
##   volumesize: "100"
##   volumetype: "gp2"
def my_block_device_mappings_root(devicenamebase,volumesize,volumetype):
    block_device_mappings_root = ( BlockDeviceMapping(
        DeviceName=devicenamebase + "a1", Ebs=EBSBlockDevice(VolumeSize=volumesize, VolumeType=volumetype)
    ))
    return block_device_mappings_root
def my_block_device_mappings_ebs(count,devicenamebase,volumesize,volumetype):
    block_device_mappings_ebs = []
    block_device_mappings_ebs.append(my_block_device_mappings_root("/dev/sd","100","gp2"))
    for i in xrange(count):
        block_device_mappings_ebs.append(
            BlockDeviceMapping(
                DeviceName = devicenamebase + chr(i+98),
                Ebs = EBSBlockDevice(
                    VolumeSize = volumesize,
                    VolumeType = volumetype,
                    DeleteOnTermination = True,
        )))
    return block_device_mappings_ebs
def my_block_device_mappings_ephemeral(count,devicenamebase):
    block_device_mappings_ephemeral = []
    block_device_mappings_ephemeral.append(my_block_device_mappings_root("/dev/sd","100","gp2"))
    for i in xrange(count):
        block_device_mappings_ephemeral.append(
            BlockDeviceMapping(
                DeviceName = devicenamebase + chr(i+98),
                VirtualName= "ephemeral" + str(i)
        ))
    return block_device_mappings_ephemeral


WorkerNodeLaunchConfig = t.add_resource(LaunchConfiguration(
    "WorkerNodeLaunchConfig",
    UserData=Base64(Join("", ["#!/bin/bash -ex\n", "\n", "function error_exit\n", "{\n", " /opt/aws/bin/cfn-signal -e 1 --stack ", Ref("AWS::StackName"), " --region ", Ref("AWS::Region"), " --resource WorkerNodes\n", " exit 1\n", "}\n", "\n", "## Install and Update CloudFormation\n", "rpm -Uvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm || :\n", "yum install -y https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.amzn1.noarch.rpm\n", "yum update -y aws-cfn-bootstrap\n", "\n", "## Running setup script\n", "curl https://raw.githubusercontent.com/seanorama/hadoop-stuff/master/providers/aws/hdp-setup.sh -o /tmp/hdp-setup.sh", " || error_exit 'Failed to download setup script'\n", "chmod a+x /tmp/hdp-setup.sh\n", "/tmp/hdp-setup.sh > /tmp/hdp-setup.log 2>&1", " || error_exit 'Install failed.See hdp-setup.log for details'\n", "\n", "## Install Ambari\n", "JAVA_HOME=/etc/alternatives/java_sdk\n", "curl http://public-repo-1.hortonworks.com/ambari/centos6/1.x/updates/1.7.0/ambari.repo -o /etc/yum.repos.d/ambari.repo", " || error_exit 'Ambari repo setup failed'\n", "yum install -y ambari-agent", " || error_exit 'Ambari Agent Installation failed'\n", "sed 's/^hostname=.*/hostname=", GetAtt("AmbariNode", "PrivateDnsName"), "/' -i /etc/ambari-agent/conf/ambari-agent.ini\n", "service ambari-agent start", " || error_exit 'Ambari Agent start-up failed'\n", "\n", "## If all went well, signal success\n", "/opt/aws/bin/cfn-signal -e 0 --stack ", Ref("AWS::StackName"), " --region ", Ref("AWS::Region"), " --resource WorkerNodes\n", "\n", "## Reboot Server\n", "reboot"])),
    ImageId=FindInMap("RHEL66", Ref("AWS::Region"), "AMI"),
    BlockDeviceMappings=If( "WorkerUseEBSBool",my_block_device_mappings_ebs(9,"/dev/sd","1000","gp2"),my_block_device_mappings_ephemeral(24,"/dev/sd")),
    KeyName=Ref(KeyName),
    SecurityGroups=[Ref("DefaultSecurityGroup")],
    IamInstanceProfile=Ref("NodeInstanceProfile"),
    InstanceType=Ref(WorkerInstanceType),
    AssociatePublicIpAddress="true",
))

AmbariNode = t.add_resource(Instance(
    "AmbariNode",
    UserData=Base64(Join("", ["#!/usr/bin/env bash\n", "region=\"", Ref("AWS::Region"), "\"\n", "stack=\"", Ref("AWS::StackName"), "\"\n", "resource=AmbariNode\n", "\n", "error_exit() {\n", "  local line_no=$1\n", "  local exit_code=$2\n", "  /opt/aws/bin/cfn-signal -e ${exit_code}", "     --region ${region}", "     --stack ${stack}", "     --resource ${resource}\n", "  exit ${exit_code}\n", "}\n", "trap 'error_exit ${LINENO} ${?}' ERR\n", "\n", "## Install and Update CloudFormation\n", "rpm -Uvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm || :\n", "yum install -y https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.amzn1.noarch.rpm\n", "yum update -y aws-cfn-bootstrap\n", "\n", "## Running setup script\n", "curl https://raw.githubusercontent.com/seanorama/hadoop-stuff/master/providers/aws/hdp-setup.sh -o /tmp/hdp-setup.sh", " || error_exit 'Failed to download setup script'\n", "chmod a+x /tmp/hdp-setup.sh\n", "/tmp/hdp-setup.sh > /tmp/hdp-setup.log 2>&1", " || error_exit 'Install failed.See hdp-setup.log for details'\n", "\n", "## Install Ambari\n", "JAVA_HOME=/etc/alternatives/java_sdk\n", "curl http://public-repo-1.hortonworks.com/ambari/centos6/1.x/updates/1.7.0/ambari.repo -o /etc/yum.repos.d/ambari.repo", " || error_exit 'Ambari repo setup failed'\n", "yum install -y ambari-agent", " || error_exit 'Ambari Agent Installation failed'\n", "sed 's/^hostname=.*/hostname=127.0.0.1/' -i /etc/ambari-agent/conf/ambari-agent.ini\n", "service ambari-agent start", " || error_exit 'Ambari Agent start-up failed'\n", "\n", "yum install -y ambari-server", " || error_exit 'Ambari Server Installation failed'\n", "ambari-server setup -j ${JAVA_HOME} -s", " || error_exit 'Ambari Server setup failed'\n", "service ambari-server start", " || error_exit 'Ambari Server start-up failed'\n", "\n", "## If all went well, signal success\n", "/opt/aws/bin/cfn-signal -e $? ", "   --region ${region}", "   --stack ${stack}", "   --resource ${resource}\n", "\n", "## Reboot Server\n", "reboot"])),
    ImageId=FindInMap("RHEL66", Ref("AWS::Region"), "AMI"),
    BlockDeviceMappings=[my_block_device_mappings_root("/dev/sd","100","gp2")],
    KeyName=Ref(KeyName),
    IamInstanceProfile=Ref(AmbariInstanceProfile),
    InstanceType=Ref(AmbariInstanceType),
    NetworkInterfaces=[
    NetworkInterfaceProperty(
        DeleteOnTermination="true",
        DeviceIndex="0",
        SubnetId=Ref(PublicSubnet),
        GroupSet=[Ref("AmbariSecurityGroup")],
        AssociatePublicIpAddress="true",
    ),
    ],
))

PublicRouteTable = t.add_resource(RouteTable(
    "PublicRouteTable",
    VpcId=Ref("VPC"),
))

DefaultSecurityGroup = t.add_resource(SecurityGroup(
    "DefaultSecurityGroup",
    SecurityGroupIngress=[{ "ToPort": "-1", "IpProtocol": "icmp", "CidrIp": FindInMap("SubnetConfig", "VPC", "CIDR"), "FromPort": "-1" }, { "ToPort": "65535", "IpProtocol": "tcp", "CidrIp": FindInMap("SubnetConfig", "VPC", "CIDR"), "FromPort": "0" }, { "ToPort": "65535", "IpProtocol": "udp", "CidrIp": FindInMap("SubnetConfig", "VPC", "CIDR"), "FromPort": "0" }, { "ToPort": "22", "IpProtocol": "tcp", "CidrIp": Ref(SSHLocation), "FromPort": "22" }],
    VpcId=Ref("VPC"),
    GroupDescription="Default Security group for all the Nodes",
))

PublicRoute = t.add_resource(Route(
    "PublicRoute",
    GatewayId=Ref("InternetGateway"),
    DestinationCidrBlock="0.0.0.0/0",
    RouteTableId=Ref(PublicRouteTable),
    DependsOn="AttachGateway",
))

AmbariAccessRole = t.add_resource(Role(
    "AmbariAccessRole",
    Path="/",
    AssumeRolePolicyDocument={ "Statement": [{ "Action": ["sts:AssumeRole"], "Effect": "Allow", "Principal": { "Service": ["ec2.amazonaws.com"] } }] },
))

WorkerNodes = t.add_resource(AutoScalingGroup(
    "WorkerNodes",
    DesiredCapacity=Ref(WorkerInstanceCount),
    MinSize=1,
    MaxSize=Ref(WorkerInstanceCount),
    VPCZoneIdentifier=[Ref(PublicSubnet)],
    LaunchConfigurationName=Ref(WorkerNodeLaunchConfig),
    AvailabilityZones=[GetAtt(PublicSubnet, "AvailabilityZone")],
    DependsOn="AmbariNode",
))

PublicSubnetRouteTableAssociation = t.add_resource(SubnetRouteTableAssociation(
    "PublicSubnetRouteTableAssociation",
    SubnetId=Ref(PublicSubnet),
    RouteTableId=Ref(PublicRouteTable),
))

InternetGateway = t.add_resource(InternetGateway(
    "InternetGateway",
))

VPC = t.add_resource(VPC(
    "VPC",
    EnableDnsSupport="true",
    CidrBlock=FindInMap("SubnetConfig", "VPC", "CIDR"),
    EnableDnsHostnames="true",
))

S3RolePolicies = t.add_resource(PolicyType(
    "S3RolePolicies",
    PolicyName="s3access",
    PolicyDocument={ "Statement": [{ "Action": "s3:*", "Resource": "*", "Effect": "Allow" }] },
    Roles=[Ref(AmbariAccessRole), Ref(NodeAccessRole)],
))

NodeInstanceProfile = t.add_resource(InstanceProfile(
    "NodeInstanceProfile",
    Path="/",
    Roles=[Ref(NodeAccessRole)],
))

MasterNode = t.add_resource(Instance(
    "MasterNode",
    UserData=Base64(Join("", ["#!/bin/bash\n", "\n", "function error_exit\n", "{\n", " /opt/aws/bin/cfn-signal -e 1 --stack ", Ref("AWS::StackName"), " --region ", Ref("AWS::Region"), " --resource MasterNode\n", " exit 1\n", "}\n", "\n", "## Install and Update CloudFormation\n", "rpm -Uvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm || :\n", "yum install -y https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.amzn1.noarch.rpm\n", "yum update -y aws-cfn-bootstrap\n", "\n", "## Running setup script\n", "curl https://raw.githubusercontent.com/seanorama/hadoop-stuff/master/providers/aws/hdp-setup.sh -o /tmp/hdp-setup.sh", " || error_exit 'Failed to download setup script'\n", "chmod a+x /tmp/hdp-setup.sh\n", "/tmp/hdp-setup.sh > /tmp/hdp-setup.log 2>&1", " || error_exit 'Install failed.See hdp-setup.log for details'\n", "\n", "## Install Ambari\n", "JAVA_HOME=/etc/alternatives/java_sdk\n", "curl http://public-repo-1.hortonworks.com/ambari/centos6/1.x/updates/1.7.0/ambari.repo -o /etc/yum.repos.d/ambari.repo", " || error_exit 'Ambari repo setup failed'\n", "yum install -y ambari-agent", " || error_exit 'Ambari Agent Installation failed'\n", "sed 's/^hostname=.*/hostname=", GetAtt(AmbariNode, "PrivateDnsName"), "/' -i /etc/ambari-agent/conf/ambari-agent.ini\n", "service ambari-agent start", " || error_exit 'Ambari Agent start-up failed'\n", "\n", "## If all went well, signal success\n", "/opt/aws/bin/cfn-signal -e 0 --stack ", Ref("AWS::StackName"), " --region ", Ref("AWS::Region"), " --resource MasterNode\n", "\n", "## Reboot Server\n", "reboot"])),
    ImageId=FindInMap("RHEL66", Ref("AWS::Region"), "AMI"),
    BlockDeviceMappings=If( "MasterUseEBSBool",
        my_block_device_mappings_ebs(2,"/dev/sd","500","gp2"),
        my_block_device_mappings_ephemeral(24,"/dev/sd")),
    KeyName=Ref(KeyName),
    IamInstanceProfile=Ref(NodeInstanceProfile),
    InstanceType=Ref(MasterInstanceType),
    NetworkInterfaces=[
    NetworkInterfaceProperty(
        DeleteOnTermination="true",
        DeviceIndex="0",
        SubnetId=Ref(PublicSubnet),
        GroupSet=[Ref(DefaultSecurityGroup)],
        AssociatePublicIpAddress="true",
    ),
    ],
    DependsOn="AmbariNode",
))

AmbariSecurityGroup = t.add_resource(SecurityGroup(
    "AmbariSecurityGroup",
    SecurityGroupIngress=[{ "ToPort": "80", "IpProtocol": "tcp", "CidrIp": "0.0.0.0/0", "FromPort": "80" }, { "ToPort": "8080", "IpProtocol": "tcp", "CidrIp": "0.0.0.0/0", "FromPort": "8080" }, { "ToPort": "-1", "IpProtocol": "icmp", "CidrIp": "10.0.0.0/24", "FromPort": "-1" }, { "ToPort": "65535", "IpProtocol": "tcp", "CidrIp": "10.0.0.0/24", "FromPort": "0" }, { "ToPort": "65535", "IpProtocol": "udp", "CidrIp": "10.0.0.0/24", "FromPort": "0" }, { "ToPort": "22", "IpProtocol": "tcp", "CidrIp": Ref(SSHLocation), "FromPort": "22" }],
    VpcId=Ref(VPC),
    GroupDescription="Access for the Ambari Nodes",
))

AttachGateway = t.add_resource(VPCGatewayAttachment(
    "AttachGateway",
    VpcId=Ref(VPC),
    InternetGatewayId=Ref(InternetGateway),
))

EC2RolePolicies = t.add_resource(PolicyType(
    "EC2RolePolicies",
    PolicyName="EC2Access",
    PolicyDocument={ "Statement": [{ "Action": ["ec2:Describe*"], "Resource": ["*"], "Effect": "Allow" }] },
    Roles=[Ref(AmbariAccessRole)],
))

Subnet = t.add_output(Output(
    "Subnet",
    Value=Ref(PublicSubnet),
))

print(t.to_json())
