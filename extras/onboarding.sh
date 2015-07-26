#!/usr/bin/env bash

users=${users:-jimmy}

# sudo sudo -u hdfs kinit -kt /etc/security/keytabs/hdfs.headless.keytab hdfs

for user in ${users}; do
  dfs_cmd="sudo sudo -u hdfs hadoop fs"
    if ! ${dfs_cmd} -stat /user/${user}; then
      ${dfs_cmd} -mkdir -p "/user/${user}"
      ${dfs_cmd} -chown "${user}" "/user/${user}" &
    fi
done

