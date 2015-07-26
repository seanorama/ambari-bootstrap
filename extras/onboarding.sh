#!/usr/bin/env bash

#users="$(getent passwd|awk -F: '$3>499{print $1}')"
users=${users:-jimmy}

dfs_cmd="sudo sudo -u hdfs hadoop fs"
# sudo sudo -u hdfs kinit -kt /etc/security/keytabs/hdfs.headless.keytab hdfs
for user in ${users}; do
    if ! ${dfs_cmd} -stat /user/${user}; then
      ${dfs_cmd} -mkdir -p "/user/${user}"
      ${dfs_cmd} -chown "${user}" "/user/${user}" &
    fi
done

