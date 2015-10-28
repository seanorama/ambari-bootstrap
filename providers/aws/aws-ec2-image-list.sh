ami_name='CentOS Linux 7 x86_64 HVM EBS 20150928_01-b7ee8a69-ee97-4a49-9e68-afaee216db2e-ami-69327e0c.2'
regions=$(aws ec2 describe-regions --output text --query 'Regions[*].RegionName')

for region in ${regions}; do
    ami_id=$(aws --region ${region} ec2 describe-images --query "Images[0].ImageId" --filters Name=name,Values="${ami_name}")
    echo \"${region}\": {\"AMI\": "${ami_id}"},
done
