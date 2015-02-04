# fabfile.py
# requires Fabric and awscli
from fabric.api import local

def generate_templates():
    local('python ./cfn-generate-template.py')

def upload_s3():
    """Stage to S3"""
    #local('aws s3 mb s3://ambari-bootstrap')
    local("aws s3 sync --delete . s3://ambari-bootstrap/providers/aws/ \
            --exclude '.DS_Store' \
            --exclude '.git*' --exclude '*' \
            --include 'generated/*.json' \
            --include 'ambari-deploy-blueprint.sh'")
