#!/usr/bin/env bash

# Author: Sean Roberts http://github.com/seanorama
# Description: Sync Ambari LDAP (using existing users & groups)
#
# Made for use in automation and scheduling as it's non-interactice.
#
# Example for cron to run hourly: Place following in /etc/cron.d/ambari-ldap-sync
# ```
# # put your variable overrides, such as ambari_pass in /root/.ambari.conf
# 0 * * * * root source /root/.ambari.conf ; /root/bin/ambari-ldap-sync > /dev/null
# ``` 

set -o errexit
set -o nounset
set -o pipefail

: ${ambari_user:="admin"}
: ${ambari_pass:="admin"}
: ${ambari_protocol:="http"}
: ${ambari_host:="localhost"}
: ${ambari_port:="8080"}
: ${ambari_api_base:="/api/v1"}
: ${ambari_api:="${ambari_protocol}://${ambari_host}:${ambari_port}${ambari_api_base}"}
: ${ambari_curl_cmd:="curl -u ${ambari_user}:${ambari_pass} -H x-requested-by:hwx-sync-ldap"}
: ${ambari_curl:="${ambari_curl_cmd} ${ambari_api}"}

read -r -d '' body <<EOF || echo ${body}
[
  {
    "Event": {
      "specs": [
        {
          "principal_type": "users",
          "sync_type": "existing"
        },
        {
          "principal_type": "groups",
          "sync_type": "existing"
        }
      ]
    }
  }
]
EOF

echo ${body} | ${ambari_curl}/ldap_sync_events -X POST -d @-

exit 0

#read -r -d '' body <<EOF
#[
  #{
    #"Event": {
      #"specs": [
        #{
          #"principal_type": "users",
          #"sync_type": "specific",
          #"names": "user1,user2"
        #},
        #{
          #"principal_type": "groups",
          #"sync_type": "specific",
          #"names": "hadoop_users,hadoop_admins"
        #}
      #]
    #}
  #}
#]
#EOF

