#!/usr/bin/env bash

## updates my default proxyusers to fit with my LDAP/AD groups

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__root="$(cd "$(dirname "${__dir}")" && pwd)" # <-- change this
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"

source ${__dir}/../ambari_functions.sh

ambari-configs

## granting root super user rights
users="hbase hcat hive HTTP knox"
for user in ${users}; do
  ${ambari_config_set} core-site hadoop.proxyuser.${user}.groups "users,hadoop-users"
  ${ambari_config_set} core-site hadoop.proxyuser.${user}.hosts "*"
done

