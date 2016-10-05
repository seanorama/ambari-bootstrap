#!/usr/bin/env bash

ambari_user=${ambari_user:-ambari}


getent passwd ${ambari_user} > /dev/null
if [ $? -eq 0 ]; then
    sudo usermod -a -G hadoop ${ambari_user}
    printf "y\ny\n${ambari_user}\nn\nn\n" | sudo ambari-server setup
else
    useradd -d /var/lib/ambari-server -G hadoop -M -r -s /sbin/nologin ${ambari_user}
    printf "y\ny\n${ambari_user}\nn\nn\n" | sudo ambari-server setup
    echo "No, the user does not exist"
fi

