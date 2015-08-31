#!/usr/bin/env bash

## Configures Ambari Kerberos JAAS
##
## How to use:
## - Replace the sample 'ambari.keytab' or ${keytab} with your keytab
## - It's 1st recommended to set Ambari as non-root
## - Realm is detected from /etc/krb5.conf. Override if needed.

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"

keytabdir=${keytabdir:-/etc/security/keytabs}
realm=${realm:-$(awk -F= 'match($1,/\w*default_realm\w*/) {print $2}' /etc/krb5.conf | tr -d '[[:space:]]')}
ambari_user=${ambari_user:-$(awk -F= '$1=="ambari-server.user" {print $2}' /etc/ambari-server/conf/ambari.properties)}
keytab=${keytab:-${__dir}/${ambari_user}.keytab}
principal=${principal:-${ambari_user}@${realm}}

if [ ! -f ${keytab} ]; then
  printf "Keytab not found at: ${keytab}\nExiting.\n"
  exit 1
fi

## path to the certificate
sudo cp ${keytab} ${keytabdir}
sudo chmod 400 ${keytabdir}/${ambari_user}.keytab
sudo chown ${ambari_user} ${keytabdir}/${ambari_user}.keytab

sudo sed -i.bak -e "s/EXAMPLE.COM/${realm}/" /etc/ambari-server/conf/krb5JAASLogin.conf
printf "3\n${principal}\n\n" | sudo ambari-server setup-security

