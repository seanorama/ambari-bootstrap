#!/usr/bin/env python

# generates an AWS CloudFormation template for an
#   Apache Ambari & Hortonworks Data Platform cluster

import sys
import boto
import boto.cloudformation
import troposphere.ec2 as ec2
import troposphere.iam as iam
from troposphere import Base64, Select, FindInMap, GetAtt, Join
from troposphere import Template, Condition, Equals, And, Or, Not, If
from troposphere import Parameter, Ref, Tags, Template, Output
from troposphere.autoscaling import LaunchConfiguration, AutoScalingGroup
from troposphere.policies import CreationPolicy, ResourceSignal

# things you may want to change
ref_disk_all_root_volumesize = "100"
ref_disk_worker_ebs_diskcount = 9
ref_disk_worker_ebs_volumesize = "1000"

# Don't touch these
ref_stack_id = Ref('AWS::StackId')
ref_region = Ref('AWS::Region')
ref_stack_name = Ref('AWS::StackName')
ref_ambariserver = GetAtt('AmbariNode',
                        'PrivateDnsName')
ref_java_provider = Ref('JavaProvider')


# now the work begins
t = Template()

t.add_version("2010-09-09")

t.add_description("""\
CloudFormation template to Deploy Hortonworks Data Platform on VPC with a public subnet""")

## Parameters

InstanceType = t.add_parameter(Parameter(
    "InstanceType",
    Default="i2.4xlarge",
    ConstraintDescription="Must be a valid EC2 instance type.",
    Type="String",
    Description="Instance type for all hosts",
))

WorkerInstanceCount = t.add_parameter(Parameter(
    "WorkerInstanceCount",
    Default="3", Type="Number", MaxValue="99", MinValue="1",
    Description="Number of Worker instances",
    ))


JavaProvider = t.add_parameter(Parameter(
    "JavaProvider",
    Default="open",
    Type="String",
    Description="Provider of Java packages: open or oracle",
    AllowedValues=['open','oracle'],
    ConstraintDescription="open or oracle",
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

AmbariAccessLocation = t.add_parameter(Parameter(
    "AmbariAccessLocation",
    ConstraintDescription="Must be a valid CIDR range.",
    Description="IPs which can access Ambari. Must be CIDR notation.",
    Default="0.0.0.0/0",
    MinLength="9",
    AllowedPattern="(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})/(\\d{1,2})",
    MaxLength="18",
    Type="String",
))


KeyName = t.add_parameter(Parameter(
    "KeyName",
    ConstraintDescription="Can contain only ASCII characters.",
    Type="AWS::EC2::KeyPair::KeyName",
    Description="Name of an existing EC2 KeyPair to enable SSH access to the instance",
))

UseEBS = t.add_parameter(Parameter(
    "UseEBS",
    Default="no",
    ConstraintDescription="Must be yes or no only.",
    Type="String",
    Description="Use EBS Volumes for the Worker Node",
    AllowedValues=["yes", "no"],
))

UseEBSBool = t.add_condition("UseEBSBool", Equals(Ref(UseEBS),"yes"))

t.add_mapping("SubnetConfig",
    {'Public': {'CIDR': '10.0.0.0/24'}, 'VPC': {'CIDR': '10.0.0.0/16'}}
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

VPC = t.add_resource(ec2.VPC(
    "VPC",
    EnableDnsSupport="true",
    CidrBlock=FindInMap("SubnetConfig", "VPC", "CIDR"),
    EnableDnsHostnames="true",
))

InternetGateway = t.add_resource(ec2.InternetGateway(
    "InternetGateway",
))

PublicSubnet = t.add_resource(ec2.Subnet(
    "PublicSubnet",
    VpcId=Ref("VPC"),
    CidrBlock=FindInMap("SubnetConfig", "Public", "CIDR"),
))

CFNRolePolicies = t.add_resource(iam.PolicyType(
    "CFNRolePolicies",
    PolicyName="CFNaccess",
    PolicyDocument={ "Statement": [{ "Action": "cloudformation:Describe*", "Resource": "*", "Effect": "Allow" }] },
    Roles=[Ref("AmbariAccessRole")],
))

AmbariInstanceProfile = t.add_resource(iam.InstanceProfile(
    "AmbariInstanceProfile",
    Path="/",
    Roles=[Ref("AmbariAccessRole")],
))

NodeAccessRole = t.add_resource(iam.Role(
    "NodeAccessRole",
    Path="/",
    AssumeRolePolicyDocument={ "Statement": [{ "Action": ["sts:AssumeRole"], "Effect": "Allow", "Principal": { "Service": ["ec2.amazonaws.com"] } }] },
))

PublicRouteTable = t.add_resource(ec2.RouteTable(
    "PublicRouteTable",
    VpcId=Ref(VPC),
))

DefaultSecurityGroup = t.add_resource(ec2.SecurityGroup(
    "DefaultSecurityGroup",
    GroupDescription="Default Security group for all the Nodes",
    SecurityGroupIngress=[
        ec2.SecurityGroupRule(
            ToPort="-1", IpProtocol="icmp", CidrIp=FindInMap("SubnetConfig", "VPC", "CIDR"), FromPort="-1"
        ),
        ec2.SecurityGroupRule(
            ToPort="65535", IpProtocol="tcp", CidrIp=FindInMap("SubnetConfig", "VPC", "CIDR"), FromPort="0"
        ),
        ec2.SecurityGroupRule(
            ToPort="65535", IpProtocol="udp", CidrIp=FindInMap("SubnetConfig", "VPC", "CIDR"), FromPort="0"
        ),
        ec2.SecurityGroupRule(
            ToPort="22", IpProtocol="tcp", CidrIp=Ref(SSHLocation), FromPort="22"
        ),
    ],
    VpcId=Ref(VPC),
))

PublicRoute = t.add_resource(ec2.Route(
    "PublicRoute",
    GatewayId=Ref(InternetGateway),
    DestinationCidrBlock="0.0.0.0/0",
    RouteTableId=Ref(PublicRouteTable),
    DependsOn="AttachGateway",
))

AmbariAccessRole = t.add_resource(iam.Role(
    "AmbariAccessRole",
    Path="/",
    AssumeRolePolicyDocument={ "Statement": [{ "Action": ["sts:AssumeRole"], "Effect": "Allow", "Principal": { "Service": ["ec2.amazonaws.com"] } }] },
))

PublicSubnetRouteTableAssociation = t.add_resource(ec2.SubnetRouteTableAssociation(
    "PublicSubnetRouteTableAssociation",
    SubnetId=Ref(PublicSubnet),
    RouteTableId=Ref(PublicRouteTable),
))

S3RolePolicies = t.add_resource(iam.PolicyType(
    "S3RolePolicies",
    PolicyName="s3access",
    PolicyDocument={ "Statement": [{ "Action": "s3:*", "Resource": "*", "Effect": "Allow" }] },
    Roles=[Ref(AmbariAccessRole), Ref(NodeAccessRole)],
))

NodeInstanceProfile = t.add_resource(iam.InstanceProfile(
    "NodeInstanceProfile",
    Path="/",
    Roles=[Ref(NodeAccessRole)],
))


AmbariSecurityGroup = t.add_resource(ec2.SecurityGroup(
    "AmbariSecurityGroup",
    SecurityGroupIngress=[
        ec2.SecurityGroupRule(
            ToPort="-1", IpProtocol="icmp", CidrIp=FindInMap("SubnetConfig", "Public", "CIDR"), FromPort="-1"
        ),
        ec2.SecurityGroupRule(
            ToPort="65535", IpProtocol="tcp", CidrIp=FindInMap("SubnetConfig", "Public", "CIDR"), FromPort="0"
        ),
        ec2.SecurityGroupRule(
            ToPort="65535", IpProtocol="udp", CidrIp=FindInMap("SubnetConfig", "Public", "CIDR"), FromPort="0"
        ),
        ec2.SecurityGroupRule(
            ToPort="22", IpProtocol="tcp", CidrIp=Ref(SSHLocation), FromPort="22"
        ),
        ec2.SecurityGroupRule(
            ToPort="8080", IpProtocol="tcp", CidrIp=Ref(AmbariAccessLocation), FromPort="8080"
        ),
    ],
    VpcId=Ref(VPC),
    GroupDescription="Access for the Ambari Nodes",
))

AttachGateway = t.add_resource(ec2.VPCGatewayAttachment(
    "AttachGateway",
    VpcId=Ref(VPC),
    InternetGatewayId=Ref(InternetGateway),
))

EC2RolePolicies = t.add_resource(iam.PolicyType(
    "EC2RolePolicies",
    PolicyName="EC2Access",
    PolicyDocument={ "Statement": [{ "Action": ["ec2:Describe*"], "Resource": ["*"], "Effect": "Allow" }] },
    Roles=[Ref(AmbariAccessRole)],
))

## Functions to generate blockdevicemappings
##   count: the number of devices to map
##   devicenamebase: "/dev/sd" or "/dev/xvd"
##   volumesize: "100"
##   volumetype: "gp2"
def my_block_device_mappings_root(devicenamebase,volumesize,volumetype):
    block_device_mappings_root = (ec2.BlockDeviceMapping(
        DeviceName=devicenamebase + "a1", Ebs=ec2.EBSBlockDevice(VolumeSize=volumesize, VolumeType=volumetype)
    ))
    return block_device_mappings_root
def my_block_device_mappings_ebs(diskcount,devicenamebase,volumesize,volumetype):
    block_device_mappings_ebs = []
    block_device_mappings_ebs.append(my_block_device_mappings_root("/dev/sd",ref_disk_all_root_volumesize,"gp2"))
    for i in xrange(diskcount):
        block_device_mappings_ebs.append(
            ec2.BlockDeviceMapping(
                DeviceName = devicenamebase + chr(i+98),
                Ebs = ec2.EBSBlockDevice(
                    VolumeSize = volumesize,
                    VolumeType = volumetype,
                    DeleteOnTermination = True,
        )))
    return block_device_mappings_ebs
def my_block_device_mappings_ephemeral(diskcount,devicenamebase):
    block_device_mappings_ephemeral = []
    block_device_mappings_ephemeral.append(my_block_device_mappings_root("/dev/sd",ref_disk_all_root_volumesize,"gp2"))
    for i in xrange(diskcount):
        block_device_mappings_ephemeral.append(
            ec2.BlockDeviceMapping(
                DeviceName = devicenamebase + chr(i+98),
                VirtualName= "ephemeral" + str(i)
        ))
    return block_device_mappings_ephemeral


bootstrap_script_body = """
########################################################################
## trap errors
error_exit() {
  local line_no=$1
  local exit_code=$2
  /opt/aws/bin/cfn-signal -e ${exit_code} --region ${region} --stack ${stack} --resource ${resource}
  exit ${exit_code}
}
trap 'error_exit ${LINENO} ${?}' ERR

########################################################################
## Install and Update CloudFormation
rpm -Uvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm || :
yum install -y https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.amzn1.noarch.rpm
yum update -y aws-cfn-bootstrap

########################################################################
## AWS specific system modifications

## swappiness to 0
sysctl -w vm.swappiness=0
mkdir -p /etc/sysctl.d
cat > /etc/sysctl.d/50-swappiness.conf <<-'EOF'
## disable swapping
vm.swappiness=0
EOF

# Disable some not-required services.
chkconfig cups off
chkconfig postfix off

## Remove existing mount points
sed '/^\/dev\/xvd[b-z]/d' -i /etc/fstab

## Format emphemeral drives and create mounts
#for drv in `ls /dev/xv* | grep -v xvda`
for drv in /dev/xvd[b-z]; do
  umount ${drv} || true
  mkdir -p /mnt${drv}
  echo "${drv} /mnt${drv} ext4 defaults,noatime,nodiratime 0 0" >> /etc/fstab
  nohup mkfs.ext4 -m 0 -T largefile4 ${drv} &
done || true
wait

## Re-size root partition
##  - This will require a reboot on RHEL6
yum install -y gdisk
growpart /dev/xvda 1

## Bootstrap Ambari
yum install -y curl
curl -sSL \
  https://raw.githubusercontent.com/seanorama/ambari-bootstrap/master/ambari-bootstrap.sh \
  -o /root/ambari-bootstrap.sh
sh /root/ambari-bootstrap.sh

## Run blueprint after reboot
## TODO: this is for a future feature.

## If all went well, signal success
/opt/aws/bin/cfn-signal -e ${?} --region ${region} --stack ${stack} --resource ${resource}

## Reboot Server
reboot
"""

def my_bootstrap_script(resource,install_ambari_agent,install_ambari_server,ambari_server):
    exports = [
        "#!/usr/bin/env bash\n",
        "exec &> >(tee -a /root/cloudformation.log)\n"
        "set -o nounset\n",
        "set -o errexit\n",
        "export region='", ref_region, "'\n",
        "export stack='", ref_stack_name, "'\n",
        "export resource='", resource ,"'\n",
        "export ambari_server='", ambari_server ,"'\n",
        "export java_provider=", ref_java_provider ,"\n",
        "export install_ambari_agent=", install_ambari_agent ,"\n",
        "export install_ambari_server=", install_ambari_server ,"\n",
    ]
    return exports + bootstrap_script_body.splitlines(True)

AmbariNode = t.add_resource(ec2.Instance(
    "AmbariNode",
    UserData=Base64(Join("", my_bootstrap_script('AmbariNode','true','true','127.0.0.1'))),
    ImageId=FindInMap("RHEL66", Ref("AWS::Region"), "AMI"),
    BlockDeviceMappings=If( "UseEBSBool",
        my_block_device_mappings_ebs(ref_disk_worker_ebs_diskcount,"/dev/sd",ref_disk_worker_ebs_volumesize,"gp2"),
        my_block_device_mappings_ephemeral(24,"/dev/sd")
        ),
    CreationPolicy=CreationPolicy(
        ResourceSignal=ResourceSignal(
          Count=1,
          Timeout="PT30M"
    )),
    KeyName=Ref(KeyName),
    IamInstanceProfile=Ref(AmbariInstanceProfile),
    InstanceType=Ref(InstanceType),
    NetworkInterfaces=[
    ec2.NetworkInterfaceProperty(
        DeleteOnTermination="true",
        DeviceIndex="0",
        SubnetId=Ref(PublicSubnet),
        GroupSet=[Ref(AmbariSecurityGroup)],
        AssociatePublicIpAddress="true",
    ),
    ],
))

WorkerNodeLaunchConfig = t.add_resource(LaunchConfiguration(
    "WorkerNodeLaunchConfig",
    UserData=Base64(Join("", my_bootstrap_script('WorkerNodes','true','false',ref_ambariserver))),
    ImageId=FindInMap("RHEL66", Ref("AWS::Region"), "AMI"),
    BlockDeviceMappings=If( "UseEBSBool",
        my_block_device_mappings_ebs(ref_disk_worker_ebs_diskcount,"/dev/sd",ref_disk_worker_ebs_volumesize,"gp2"),
        my_block_device_mappings_ephemeral(24,"/dev/sd")
        ),
    KeyName=Ref(KeyName),
    SecurityGroups=[Ref("DefaultSecurityGroup")],
    IamInstanceProfile=Ref("NodeInstanceProfile"),
    InstanceType=Ref(InstanceType),
    AssociatePublicIpAddress="true",
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
    CreationPolicy=CreationPolicy(
        ResourceSignal=ResourceSignal(
          Count=Ref(WorkerInstanceCount),
          Timeout="PT30M"
    )),
))

t.add_output([
    Output(
        "AmbariURL",
        Description="URL of Ambari UI",
        Value=Join("", [
            "http://", GetAtt('AmbariNode', 'PublicDnsName'), ":8080"
        ]),
    ),
    Output(
        "AmbariSSH",
        Description="SSH to the Ambari Node",
        Value=Join("", [
            "ssh ec2-user@", GetAtt('AmbariNode', 'PublicDnsName')
        ]),
    ),
    Output(
        "AmbariServiceInstanceId",
        Description="The Ambari Servers Instance-Id",
        Value=Ref('AmbariNode')
    ),
    Output(
        "Region",
        Description="AWS Region",
        Value=ref_region
    ),
])

if __name__ == '__main__':

    template_compressed="\n".join([line.strip() for line in t.to_json().split("\n")])

    try:
        cfcon = boto.cloudformation.connect_to_region('us-west-2')
        cfcon.validate_template(template_compressed)
    except boto.exception.BotoServerError, e:
        sys.stderr.write("FATAL: CloudFormation Template Validation Error:\n%s\n" % e.message)
    else:
        sys.stderr.write("Successfully validated template!\n")
        with open('generated/cfn-ambari-jumpstart.template-uncompressed.json', 'w') as f:
            f.write(t.to_json())
        print('Uncompressed template written to generated/cfn-ambari-jumpstart.template-uncompressed.json')
        with open('generated/cfn-ambari-jumpstart.template.json', 'w') as f:
            f.write(template_compressed)
        print('Compressed template written to generated/cfn-ambari-jumpstart.template.json')
