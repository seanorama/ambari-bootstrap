#!/usr/bin/env bash
## This script imports a self-signed CA certificate
## to the system & java keystores
##
## uses my ./ca.pem by default. Replace or update $mycert with your cert

## magic dirs: don't touch
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"

## path to the certificate
mycert=${mycert:-${__dir}/ca.pem}

if [ ! -f ${mycert} ]; then
  printf "Certificate not found at: ${mycert}\nExiting.\n"
  exit 1
fi

#
sudo cp ${mycert} /etc/pki/ca-trust/source/anchors/
sudo yum -y install openldap-clients ca-certificates

## updates system & java keystores
sudo update-ca-trust force-enable
sudo update-ca-trust extract
sudo update-ca-trust check

