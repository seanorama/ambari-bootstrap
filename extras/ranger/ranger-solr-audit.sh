#!/usr/bin/env bash

mypass=${mypass:-BadPass#1}

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__root="$(cd "$(dirname "${__dir}")" && pwd)" # <-- change this
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"

source ${__dir}/../ambari_functions.sh
ambari-configs

${ambari_config_set} ranger-admin-site ranger.audit.source.type solr
${ambari_config_set} ranger-admin-site ranger.audit.solr.urls "http://localhost:8983/solr/ranger_audits"
