#!/usr/bin/env bash

sudo curl -ksSL -o /etc/ambari-agent/conf/public-hostname-gcloud.sh https://raw.githubusercontent.com/GoogleCloudPlatform/bdutil/master/platforms/hdp/resources/public-hostname-gcloud.sh
sudo sed -i.bak "/\[agent\]/ a public_hostname_script=\/etc\/ambari-agent\/conf\/public-hostname-gcloud.sh" /etc/ambari-agent/conf/ambari-agent.ini
sudo chmod +x /etc/ambari-agent/conf/public-hostname-gcloud.sh

echo "For the changes to take affect:"
echo "  service ambari-server restart"
echo

