#!/usr/bin/env bash

sudo tee "/etc/ambari-agent/conf/public-hostname-icanhazip.sh" > /dev/null <<'EOF'
curl -Ls -m 5 -4 http://icanhazip.com
EOF

sudo sed -i.bak "/\[agent\]/ a public_hostname_script=\/etc\/ambari-agent\/conf\/public-hostname-icanhazip.sh" /etc/ambari-agent/conf/ambari-agent.ini
sudo chmod +x /etc/ambari-agent/conf/public-hostname-icanhazip.sh
