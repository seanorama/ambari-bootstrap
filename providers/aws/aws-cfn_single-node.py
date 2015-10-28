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
ref_disk_all_root_volumesize = "20"
ref_disk_ambari_ebs_diskcount = 2
ref_disk_ambari_ebs_volumesize = "500"

# Don't touch these
ref_stack_id = Ref('AWS::StackId')
ref_region = Ref('AWS::Region')
ref_stack_name = Ref('AWS::StackName')
ref_java_provider = Ref('JavaProvider')
ref_java_version = Ref('JavaVersion')
ref_postscript = Ref('PostScript')

# now the work begins
t = Template()

t.add_version("2010-09-09")

t.add_description("""\
CloudFormation template to Deploy Hortonworks Data Platform on VPC with a public subnet""")

## Parameters

AmbariInstanceType = t.add_parameter(Parameter(
    "AmbariInstanceType",
    Default="m3.2xlarge",
    ConstraintDescription="Must be a valid EC2 instance type.",
    Type="String",
    Description="Instance type for Ambari node",
))

JavaProvider = t.add_parameter(Parameter(
    "JavaProvider",
    Default="open",
    Type="String",
    Description="Provider of Java packages: open or oracle",
    AllowedValues=['open','oracle'],
    ConstraintDescription="open or oracle",
))

JavaVersion = t.add_parameter(Parameter(
    "JavaVersion",
    Default="8",
    Type="String",
    Description="Version number of Java",
    AllowedValues=['7','8'],
    ConstraintDescription="7 or 8",
))

PostScript = t.add_parameter(Parameter(
    "PostScript",
    Default="/bin/true",
    Type="String",
    Description="Command you want to run after the node is deployed"
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

AmbariUseEBS = t.add_parameter(Parameter(
    "AmbariUseEBS",
    Default="no",
    ConstraintDescription="Must be yes or no only.",
    Type="String",
    Description="Use EBS Volumes for the Ambari Node",
    AllowedValues=["yes", "no"],
))


AmbariUseEBSBool = t.add_condition("AmbariUseEBSBool", Equals(Ref(AmbariUseEBS),"yes"))

t.add_mapping("SubnetConfig",
    {'Public': {'CIDR': '10.0.0.0/24'}, 'VPC': {'CIDR': '10.0.0.0/16'}}
)

t.add_mapping("CENTOS7", {
    "eu-west-1": {"AMI": "ami-33734044"},
    "ap-southeast-1": {"AMI": "ami-2a7b6b78"},
    "ap-southeast-2": {"AMI": "ami-d38dc6e9"},
    "eu-central-1": {"AMI": "ami-e68f82fb"},
    "ap-northeast-1": {"AMI": "ami-b80b6db8"},
    "us-east-1": {"AMI": "ami-61bbf104"},
    "sa-east-1": {"AMI": "ami-fd0197e0"},
    "us-west-1": {"AMI": "ami-f77fbeb3"},
    "us-west-2": {"AMI": "ami-d440a6e7"}
})

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
  cfn-signal -e ${exit_code} --region ${region} --stack ${stack} --resource ${resource}
  exit ${exit_code}
}
trap 'error_exit ${LINENO} ${?}' ERR

########################################################################
## Install and Update CloudFormation
yum install -y epel-release
/usr/bin/easy_install https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-latest.tar.gz

########################################################################
## AWS specific system modifications

## swappiness to 0
sysctl -w vm.swappiness=0
mkdir -p /etc/sysctl.d
cat > /etc/sysctl.d/50-swappiness.conf <<-'EOF'
## disable swapping
vm.swappiness=0
EOF

## Remove existing mount points
sed '/^\/dev\/xvd[b-z]/d' -i /etc/fstab

## Format emphemeral drives and create mounts
for drv in /dev/xvd[b-z]; do
  umount ${drv} || true
  mkdir -p /mnt${drv}
  echo "${drv} /mnt${drv} ext4 defaults,noatime,nodiratime 0 0" >> /etc/fstab
  nohup mkfs.ext4 -m 0 -T largefile4 $drv &
done
wait

## Deploy Cluster for SQL masterclass
$postscript || true

## If all went well, signal success
cfn-signal -e ${?} --region ${region} --stack ${stack} --resource ${resource}
"""

def my_bootstrap_script(resource,install_ambari_agent,install_ambari_server,ambari_server):
    exports = [
        "#!/usr/bin/env bash\n",
        "exec &> >(tee -a /root/cloudformation.log)\n"
        "set -o nounset\n",
        "set -o errexit\n",
        "export postscript='", ref_postscript, ",\n",
        "export region='", ref_region, "'\n",
        "export stack='", ref_stack_name, "'\n",
        "export resource='", resource ,"'\n",
        "export ambari_server='", ambari_server ,"'\n",
        "export java_provider=", ref_java_provider ,"\n",
        "export java_version=", ref_java_version ,"\n",
        "export install_ambari_agent=", install_ambari_agent ,"\n",
        "export install_ambari_server=", install_ambari_server ,"\n",
    ]
    return exports + bootstrap_script_body.splitlines(True)

AmbariNode = t.add_resource(ec2.Instance(
    "AmbariNode",
    UserData=Base64(Join("", my_bootstrap_script('AmbariNode','true','true','127.0.0.1'))),
    ImageId=FindInMap("CENTOS7", Ref("AWS::Region"), "AMI"),
    BlockDeviceMappings=If( "AmbariUseEBSBool",
        my_block_device_mappings_ebs(ref_disk_ambari_ebs_diskcount,"/dev/sd",ref_disk_ambari_ebs_volumesize,"gp2"),
        my_block_device_mappings_ephemeral(24,"/dev/sd")),
    CreationPolicy=CreationPolicy(
        ResourceSignal=ResourceSignal(
          Count=1,
          Timeout="PT30M"
    )),
    KeyName=Ref(KeyName),
    IamInstanceProfile=Ref(AmbariInstanceProfile),
    InstanceType=Ref(AmbariInstanceType),
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
            "ssh centos@", GetAtt('AmbariNode', 'PublicDnsName')
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
        with open('generated/aws-cfn_single-node.template-uncompressed.json', 'w') as f:
            f.write(t.to_json())
        print('Uncompressed template written to generated/cfn-ambari.template-uncompressed.json')
        with open('generated/aws-cfn_single-node.template.json', 'w') as f:
            f.write(template_compressed)
        print('Compressed template written to generated/cfn-ambari.template.json')
