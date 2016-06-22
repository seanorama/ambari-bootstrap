#!/usr/bin/env bash

mypass=${mypass:-BadPass#1}

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__root="$(cd "$(dirname "${__dir}")" && pwd)" # <-- change this
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"

source ${__dir}/../ambari_functions.sh

ambari_configs

## Ranger ugsync
${ambari_config_set} ranger-ugsync-site ranger.usersync.ldap.ldapbindpassword "${mypass}"
${ambari_config_set} ranger-ugsync-site ranger.usersync.ldap.searchBase "dc=hortonworks,dc=com"
${ambari_config_set} ranger-ugsync-site ranger.usersync.source.impl.class ldap
${ambari_config_set} ranger-ugsync-site ranger.usersync.ldap.binddn "CN=ldap-connect,OU=users,OU=hdp,DC=hortonworks,DC=com"
${ambari_config_set} ranger-ugsync-site ranger.usersync.ldap.url "ldap://activedirectory.hortonworks.com"
${ambari_config_set} ranger-ugsync-site ranger.usersync.ldap.user.nameattribute "sAMAccountName"
${ambari_config_set} ranger-ugsync-site ranger.usersync.ldap.user.searchbase "dc=hortonworks,dc=com"
${ambari_config_set} ranger-ugsync-site ranger.usersync.group.searchbase "dc=hortonworks,dc=com"
${ambari_config_set} ranger-ugsync-site ranger.usersync.ldap.user.searchfilter "(objectcategory=person)"
${ambari_config_set} ranger-ugsync-site ranger.usersync.ldap.user.groupnameattribute "memberof, ismemberof, msSFU30PosixMemberOf"
${ambari_config_set} ranger-ugsync-site ranger.usersync.group.memberattributename member
${ambari_config_set} ranger-ugsync-site ranger.usersync.group.nameattribute cn
${ambari_config_set} ranger-ugsync-site ranger.usersync.group.objectclass group

