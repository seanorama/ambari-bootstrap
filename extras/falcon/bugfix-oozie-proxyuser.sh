#!/usr/bin/bash

## magic, don't touch
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
source ${__dir}/../ambari_functions.sh

ambari-configs

${ambari_config_set} oozie-site oozie.service.ProxyUserService.proxyuser.falcon.groups "users,hadoop-users"
${ambari_config_set} oozie-site oozie.service.ProxyUserService.proxyuser.falcon.hosts "*"
