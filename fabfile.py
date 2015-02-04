# fabfile.py
# requires Fabric and awscli
from fabric.api import local

def upload_s3():
    """Stage to S3"""
    #local('aws s3 mb s3://ambari-bootstrap')
    local("aws s3 sync . s3://ambari-bootstrap \
            --exclude '.DS_Store' \
            --exclude '.git*' --exclude '*' \
            --include 'ambari-bootstrap*.sh'")
