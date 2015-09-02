#!/usr/bin/env bash
##
## Messy automation:
##   Enable Kerberos for HDP using Ambari's Kerberos API
##
## Tested with Ambari 2.1.(0|1) & HDP 2.3.0 & CentOS 6.7
##

########################################################################
## Config: Update or `export` in your shell environment before executing the script
ad_pass=${ad_pass:-BadPass#1}
ad_user=${ad_user:-lab01admin} ## this is your admin user
realm=${realm:-HORTONWORKS.COM}
ad_principal=${ad_principal:-"${ad_user}@${realm}"}
ad_root="${ad_root:-dc=hortonworks,dc=com}"
ad_ou="${ad_ou:-ou=lab01,ou=labs,${ad_root}}"
admin_host=${admin_host:-activedirectory.hortonworks.com}
kdc_host=${kdc_host:-${admin_host}}
kdc_type=${kdc_type:-"active-directory"}
ldap_url=${ldap_url:-"ldaps://${admin_host}"}
if [ ! ${realm,,} == "$(hostname -d)" ]; then
  domains=${domains:-"$(hostname -d),.$(hostname -d)"}
fi

########################################################################
########################################################################
########################################################################
########################################################################

########################################################################
## Don't Touch: Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
source ${__dir}/../ambari_functions.sh
ambari-configs

${ambari_curl}/clusters/${ambari_cluster}/services/KERBEROS -X POST
${ambari_curl}/clusters/${ambari_cluster}/services/KERBEROS/components/KERBEROS_CLIENT -X POST

########################################################################
action="Uploading config kerberos-env"

echo ${action}
read -r -d '' body <<EOF
[ { "Clusters": { "desired_config": { "type": "kerberos-env",
        "tag": "version1",
        "properties": {
          "ad_create_attributes_template" : "\n{\n \"objectClass\": [\"top\", \"person\", \"organizationalPerson\", \"user\"],\n \"cn\": \"\$principal_name\",\n #if( \$is_service )\n \"servicePrincipalName\": \"\$principal_name\",\n #end\n \"userPrincipalName\": \"\$normalized_principal\",\n \"unicodePwd\": \"\$password\",\n \"accountExpires\": \"0\",\n \"userAccountControl\": \"66048\"\n}",
          "admin_server_host" : "${admin_host}",
          "case_insensitive_username_rules" : "false",
          "container_dn" : "${ad_ou}",
          "encryption_types": "aes des3-cbc-sha1 rc4 des-cbc-md5",
          "executable_search_paths" : "/usr/bin, /usr/kerberos/bin, /usr/sbin, /usr/lib/mit/bin, /usr/lib/mit/sbin",
          "install_packages": "true",
          "kdc_create_attributes" : "",
          "kdc_host" : "${kdc_host}",
          "kdc_type" : "${kdc_type}",
          "ldap_url" : "${ldap_url}",
          "manage_identities": "true",
          "password_length": "20",
          "password_min_digits": "1",
          "password_min_lowercase_letters": "1",
          "password_min_punctuation": "1",
          "password_min_uppercase_letters": "1",
          "password_min_whitespace": "0",
          "realm" : "${realm}",
          "service_check_principal_name" : "\${cluster_name}-\${short_date}"
        }
} } } ]
EOF
echo "${body}" | ${ambari_curl}/clusters/${ambari_cluster} -X PUT -d @-

########################################################################
action="Uploading config krb5-conf"

echo ${action}
read -r -d '' body <<EOF
[ { "Clusters": { "desired_config": { "type": "krb5-conf",
        "tag": "version1",
        "properties": {
            "conf_dir" : "/etc",
            "content" : "\n[libdefaults]\n  renew_lifetime = 7d\n  forwardable = true\n  default_realm = {{realm}}\n  ticket_lifetime = 24h\n  dns_lookup_realm = false\n  dns_lookup_kdc = false\n  #default_tgs_enctypes = {{encryption_types}}\n  #default_tkt_enctypes = {{encryption_types}}\n\n{% if domains %}\n[domain_realm]\n{% for domain in domains.split(',') %}\n  {{domain}} = {{realm}}\n{% endfor %}\n{% endif %}\n\n[logging]\n  default = FILE:/var/log/krb5kdc.log\n  admin_server = FILE:/var/log/kadmind.log\n  kdc = FILE:/var/log/krb5kdc.log\n\n[realms]\n  {{realm}} = {\n    admin_server = {{admin_server_host|default(kdc_host, True)}}\n    kdc = {{kdc_host}}\n  }\n\n{# Append additional realm declarations below #}",
            "domains" : "${domains}",
            "manage_krb5_conf" : "true"
        }
} } } ]
EOF
echo "${body}" | ${ambari_curl}/clusters/${ambari_cluster} -X PUT -d @-

########################################################################
action="Installing KERBEROS_CLIENT"

echo ${action}

## gets list of hosts
hosts=$(${ambari_curl}/clusters/${ambari_cluster}/hosts?Hosts/host_name \
| python -c 'import json,sys; obj=json.load(sys.stdin)
for y in [x["Hosts"]["host_name"] for x in obj["items"]]:
    print y
')

read -r -d '' body <<EOF
{"host_components" : [{"HostRoles" : {"component_name":"KERBEROS_CLIENT"}}]}
EOF
for host in ${hosts}; do
    echo "${body}" | ${ambari_curl}/clusters/${ambari_cluster}/hosts?Hosts/host_name=${host} -X POST -d @-
done

########################################################################
action="Installing KERBEROS service"

echo ${action}
read -r -d '' body <<EOF
{"ServiceInfo": {"state" : "INSTALLED"}}
EOF
response=$(echo "${body}" | ${ambari_curl}/clusters/${ambari_cluster}/services/KERBEROS -X PUT -d @-)

if [ $? != 0 ]; then echo "Error while ${action}"; exit 1; fi

request_id=$(echo ${response} | python -c 'import sys,json; print json.load(sys.stdin)["Requests"]["id"]')
ambari_wait_request_complete ${request_id}

########################################################################
action="Stopping cluster services"

echo ${action}
read -r -d '' body <<EOF
{"ServiceInfo": {"state" : "INSTALLED"}}
EOF
response=$(echo "${body}" | ${ambari_curl}/clusters/${ambari_cluster}/services -X PUT -d @-)

if [ $? != 0 ]; then echo "Error while ${action}"; exit 1; fi

request_id=$(echo ${response} | python -c 'import sys,json; print json.load(sys.stdin)["Requests"]["id"]')
ambari_wait_request_complete ${request_id}

########################################################################
action="Enabling Kerberos"
echo ${action}

read -r -d '' body <<EOF
{
  "session_attributes" : {
    "kerberos_admin" : {
      "principal" : "${ad_principal}", "password" : "${ad_pass}" }
    },
    "Clusters": {
      "security_type" : "KERBEROS"
  }
}
EOF
response=$(echo "${body}" | ${ambari_curl}/clusters/${ambari_cluster} -X PUT -d @-)

if [ $? != 0 ]; then echo "Error while ${action}"; exit 1; fi

request_id=$(echo ${response} | python -c 'import sys,json; print json.load(sys.stdin)["Requests"]["id"]')
ambari_wait_request_complete ${request_id}


########################################################################
action="Starting Cluster Services"
echo ${action}

read -r -d '' body <<EOF
{"ServiceInfo": {"state" : "STARTED"}}
EOF
response=$(echo "${body}" | ${ambari_curl}/clusters/${ambari_cluster}/services -X PUT -d @-)

if [ $? != 0 ]; then echo "Error while ${action}"; exit 1; fi

request_id=$(echo ${response} | python -c 'import sys,json; print json.load(sys.stdin)["Requests"]["id"]')
ambari_wait_request_complete ${request_id}

########################################################################
echo Done

