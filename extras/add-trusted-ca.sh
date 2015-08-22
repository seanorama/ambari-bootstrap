#!/usr/bin/env bash
## This script imports a self-signed CA certificate
## to the system & java keystores

## Ensure your cert exists within /etc/pki/ca-trust/source/anchors
##   I prefer to load with automation or curl, for example:
##   sudo curl -sSL -o ${mycert} https://....../activedirectory.pem
mycert=${mycert:-/etc/pki/ca-trust/source/anchors/activedirectory.pem}

if [ ! -f ${mycert} ]; then
  printf "Certificate not found at: ${mycert}\nExiting.\n"
  exit 1
fi

sudo yum -y install openldap-clients ca-certificates

## System keystore
sudo update-ca-trust enable
sudo update-ca-trust extract; sudo update-ca-trust check

## Java keystore. Requires Java to be installed first.
if command -v keytool; then
  sudo keytool -importcert -noprompt -storepass changeit \
    -file ${mycert} -alias ad -keystore /etc/pki/java/cacerts
fi

