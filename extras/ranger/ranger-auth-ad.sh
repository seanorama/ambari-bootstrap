#!/usr/bin/env bash

mypass=${mypass:-BadPass#1}

####
## Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__root="$(cd "$(dirname "${__dir}")" && pwd)" # <-- change this
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"

source ${__dir}/../ambari_functions.sh
ambari_configs
ambari_get_cluster

#keystore=/etc/ranger/admin/rangeradmin.jceks
#xa_ldap_ad_bind_password="BadPass#1"
#ad_password_alias=ranger.ad.binddn.password
#java -cp "cred/lib/*" org.apache.ranger.credentialapi.buildks create \
#    "${ad_password_alias}" -value "${xa_ldap_ad_bind_password}" \
#    -provider jceks://file${keystore}

ranger_host=$(${ambari_curl}/clusters/${ambari_cluster}/services/RANGER/components/RANGER_ADMIN?fields=host_components/HostRoles/host_name\&minimal_response=true \
    | python -c 'import sys,json; \
    print json.load(sys.stdin)["host_components"][0]["HostRoles"]["host_name"]')

${ambari_config_set} ranger-admin-site ranger.authentication.method ACTIVE_DIRECTORY
${ambari_config_set} ranger-admin-site ranger.ldap.ad.domain hortonworks.com
${ambari_config_set} ranger-admin-site ranger.ldap.ad.url "ldap://activedirectory.hortonworks.com:389"
${ambari_config_set} ranger-admin-site ranger.ldap.ad.base.dn "dc=hortonworks,dc=com"
${ambari_config_set} ranger-admin-site ranger.ldap.ad.bind.dn "cn=ldap-connect,ou=users,ou=hdp,dc=hortonworks,dc=com"
${ambari_config_set} ranger-admin-site ranger.ldap.ad.referral follow
${ambari_config_set} ranger-admin-site ranger.ldap.ad.bind.password "${mypass}"

#${ambari_config_set} ranger-admin-site ranger.ldap.ad.bind.password "_"
#${ambari_config_set} ranger-admin-site ranger.ldap.ad.binddn.credential.alias "${ad_password_alias}"
