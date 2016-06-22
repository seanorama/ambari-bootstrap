#!/usr/bin/env bash

__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__root="$(cd "$(dirname "${__dir}")" && pwd)" # <-- change this
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"

##
source ${__dir}/ambari_functions.sh
ambari_configs

realm=$(${ambari_config_get} kerberos-env | awk -F'"' '$2 == "realm" {print $4}' | head -1)
if [ -z "${realm}"  ]; then
  sudo sudo -u hdfs kinit -kt /etc/security/keytabs/hdfs.headless.keytab hdfs-${ambari_cluster}
fi

UID_MIN=$(awk '$1=="UID_MIN" {print $2}' /etc/login.defs)
users="${users:-$(getent passwd|awk -v UID_MIN="${UID_MIN}" -F: '$3>=UID_MIN{print $1}')}"
#export users=${users:-jimmy}
#export users=$(ldapsearch -Q "(memberOf=CN=hadoop-users,OU=users,OU=hdp,DC=hortonworks,DC=com)" sAMAccountName | awk '/^sAMAccountName: / {print $2}')

dfs_cmd="sudo sudo -u hdfs hadoop fs"
for user in ${users}; do
    if ! ${dfs_cmd} -stat /user/${user}; then
      ${dfs_cmd} -mkdir -p "/user/${user}"
      ${dfs_cmd} -chown "${user}" "/user/${user}" &
    fi
done

