#!/usr/bin/env bash

## Simply preloading the ambari config with Active Directory
##   compatible settings.
##
## You'll need to update the 1st 3 settings.
##
## Then execute:
##   sudo ambari-server setup-ldap
##   sudo ambari-server restart
##   sudo ambari-agent restart
##   sudo ambari-server sync-ldap --all


cat <<-'EOF' | sudo tee -a /etc/ambari-server/conf/ambari.properties
authentication.ldap.baseDn=dc=hortonworks,dc=com
authentication.ldap.managerDn=cn=ldap-connect,ou=users,ou=hdp,dc=hortonworks,dc=com
authentication.ldap.primaryUrl=activedirectory.hortonworks.com:389
authentication.ldap.bindAnonymously=false
authentication.ldap.dnAttribute=distinguishedName
authentication.ldap.groupMembershipAttr=member
authentication.ldap.groupNamingAttr=cn
authentication.ldap.groupObjectClass=group
authentication.ldap.useSSL=false
authentication.ldap.userObjectClass=user
authentication.ldap.usernameAttribute=sAMAccountName
EOF


