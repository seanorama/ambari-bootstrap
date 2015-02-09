# fabfile.py
# requires Fabric and awscli
from fabric.api import local

def generate_templates():
    local('with-aws.sh python ./cfn-generate-template.py')

def upload_s3():
    """Stage to S3"""
    #local('aws s3 mb s3://ambari-bootstrap')
    local("with-aws.sh aws s3 sync --delete . s3://ambari-bootstrap/providers/aws/ \
            --exclude '.DS_Store' \
            --exclude '.git*' --exclude '*' \
            --include 'generated/*.json' \
            --include 'ambari-deploy-blueprint.sh'")

def stack_create():
    local("with-aws.sh aws cloudformation create-stack --stack-name hdp-test  \
        --template-body file://./generated/cfn-ambari.template.json \
        --capabilities CAPABILITY_IAM \
        --parameters  ParameterKey=AmbariInstanceType,ParameterValue=\"m3.large\" \
            ParameterKey=KeyName,ParameterValue=\"mb\" \
            ParameterKey=MasterInstanceCount,ParameterValue=1 \
            ParameterKey=WorkerInstanceCount,ParameterValue=1 \
            ParameterKey=MasterInstanceType,ParameterValue=\"m3.large\" \
            ParameterKey=WorkerInstanceType,ParameterValue=\"m3.xlarge\"")

def stack_jumpstart_create():
    local("with-aws.sh aws cloudformation create-stack --stack-name hdp-test  \
        --template-body file://./generated/cfn-ambari-jumpstart.template.json \
        --capabilities CAPABILITY_IAM \
        --parameters  ParameterKey=InstanceType,ParameterValue=\"m3.xlarge\" \
            ParameterKey=KeyName,ParameterValue=\"mb\" \
            ParameterKey=WorkerInstanceCount,ParameterValue=2")

def stack_describe():
    local("with-aws.sh aws cloudformation describe-stack-resources --stack-name hdp-test")

def stack_delete():
    local("with-aws.sh aws cloudformation delete-stack --stack-name hdp-test")
