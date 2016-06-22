#!/usr/bin/bash

## magic, don't touch
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"

source ${__dir}/../ambari_functions.sh
ambari_configs

## granting root super user rights
proxyusers="${proxyusers:-falcon}"
for user in ${proxyusers}; do
    ${ambari_config_set} oozie-site oozie.service.ProxyUserService.proxyuser.${user}.groups "users,hadoop-users"
    ${ambari_config_set} oozie-site oozie.service.ProxyUserService.proxyuser.${user}.hosts "*"
done
