#!/usr/bin/env bash

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__root="$(cd "$(dirname "${__dir}")" && pwd)" # <-- change this
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
source ${__dir}/ambari_functions.sh
ambari-configs

realm=$(${ambari_config_get} kerberos-env | awk -F'"' '$2 == "realm" {print $4}' | head -1)

sudo mv ambari.keytab /etc/security/keytabs/
sudo chmod 400 /etc/security/keytabs/ambari.keytab
sudo chown ambari /etc/security/keytabs/ambari.keytab

sudo sed -i.bak -e "s/EXAMPLE.COM/${realm}/" /etc/ambari-server/conf/krb5JAASLogin.conf

printf "3\nambari@${realm}\n\n" | sudo ambari-server setup-security

