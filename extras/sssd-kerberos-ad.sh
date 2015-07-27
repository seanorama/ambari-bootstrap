#!/usr/bin/env bash

## This script will join a computer to an active directory domain and
##   configure authentication via SSSD
##
## - You should execute on all nodes in the cluster
## - HDFS will need to be restarted after executing this script on the NameNode(s)
##

## Requirements
##
##  Kerberos already configured via Ambari Wizard for Active Directory, or manually.
##
##  Your AD user must have these rights to the container:
##    - Delegation to “Create, delete and manage user accounts”
##    - Join computers to the domain
##      - https://jonconwayuk.wordpress.com/2011/10/20/minimum-permissions-required-for-account-to-join-workstations-to-the-domain-during-deployment/
##      - http://deploymentresearch.com/Research/Post/353/PowerShell-Script-to-set-permissions-in-Active-Directory-for-OSD
##
##  Tested on CentOS6 with Ambari 2.1 & HDP 2.3
##    But should work with any system that already had a krb5.conf in place (irrelevant of HDP or Hadoop)
##

## Change these to fit your environment
ad_user=lab01admin ## this is your admin user
ad_domain=hortonworks.com
ad_workgroup=HORTONWORKS
ad_dc=activedirectory.hortonworks.com ## not required if the AD server is also your DNS server
ad_root="dc=hortonworks,dc=com"
ad_ou="ou=lab01,ou=labs,${ad_root}"

## You shouldn’t need to change anything below this

ad_realm=${ad_domain^^}
if [ -z ${ad_pass+x} ]; then 
  read -s -p "Password of ${ad_user}@${ad_realm}: " ad_pass
  echo
fi

sudo yum makecache
sudo yum -y install epel-release ## epel is required for adcli
sudo yum -y install sssd oddjob-mkhomedir authconfig sssd-krb5 sssd-ad sssd-tools libnss-sss libpam-sss
sudo yum -y install adcli

echo ${ad_pass} | sudo kinit ${ad_user}

## used adcli as it was simpler, but samba4 could work instead with some extra configuration:
# sudo net ads join -k -S ${ad_dc} -w hortonworks.com createcomputer="labs/lab01" -d 9

sudo adcli join -v \
  --domain-controller=${ad_dc} \
  --domain-ou="${ad_ou}" \
  --login-ccache="/tmp/krb5cc_0" \
  --show-details

sudo tee /etc/sssd/sssd.conf > /dev/null <<EOF
[sssd]
services = nss, pam, ssh, autofs
config_file_version = 2
domains = ${ad_realm}
override_space = _
[domain/${ad_realm}]
id_provider = ad
acess_provider = ad
## ad_server is not needed when the DC is managing DNS, so can be discovered
ad_server = ${ad_dc}
#ldap_user_principal = nosuchattribute
#ldap_search_base = ${ad_root}
EOF
sudo chmod 0600 /etc/sssd/sssd.conf

sudo authconfig --enablesssd --enablesssdauth --enablemkhomedir --enablelocauthorize --update

sudo chkconfig oddjobd on
sudo service oddjobd restart
sudo chkconfig sssd on
sudo service sssd restart

sudo kdestroy

echo You will now need to restart HDFS for it to recieve the changes and user/group mappings.

## test with:
echo su -u $(whoami)
echo id
echo hdfs groups

## $ id
## uid=1139201162(sean) gid=1139200513(domain users) groups=1139200513(domain users),1139201177(hadoop-users) context=unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023
## $ hdfs groups
## sean@HORTONWORKS.COM : domain users hadoop-users
