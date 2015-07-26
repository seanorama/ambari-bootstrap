#!/usr/bin/env bash

## This script imports a self-signed CA certificate to be trusted
##  - configures LDAP to use & provides default LDAP settings
##  - adds to local CA trust
##  - adds to java keys

## Changes needed for your use:
##   1. Path where you have saved or would like the cert saved
##   2. The URI & BASE of the LDAP configuration

sudo yum -y install openldap-clients ca-certificates

## 1. The ca certificate you are trusting
mycert=/etc/pki/ca-trust/source/anchors/activedirectory.pem
## I'm loading from a URL
#sudo curl -sSL -o ${mycert} https://....../activedirectory.pem 

## 2. LDAP configuration to use the systems PKI and a default LDAP server
sudo tee /etc/openldap/ldap.conf > /dev/null <<-EOF
URI ldaps://activedirectory.hortonworks.com
BASE dc=hortonworks,dc=com
TLS_CACERTDIR /etc/pki/tls/certs
TLS_CACERT /etc/pki/tls/certs/ca-bundle.crt
SASL_NOCANON    on
EOF
## can test with:
#ldapsearch -W -D user@domain.com


####################
## Adding the trusts

sudo update-ca-trust enable
sudo update-ca-trust extract; sudo update-ca-trust check

if command -v keytool; then
  sudo keytool -import -trustcacerts -noprompt -storepass changeit \
    -file ${mycert} -keystore /etc/pki/java/cacerts
  sudo keytool -importcert -noprompt -storepass changeit \
    -file ${mycert} -alias ad -keystore /etc/pki/java/cacerts
fi
