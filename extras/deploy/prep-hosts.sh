#!/usr/bin/env bash

: ${ambari_pass:="BadPass#1"}

sudo yum makecache
sudo yum -y -q install git epel-release screen mlocate python-configobj bind-utils
sudo yum -y -q install shellinabox mosh tmux ack jq python-argparse python-pip
sudo pip install --upgrade pip
sudo pip install httpie

## shell in a box, web based console on port 4200
sudo chkconfig shellinaboxd on
#sudo sed -i.bak 's/^\(OPTS=.*\):LOGIN/\1:SSH/' /etc/sysconfig/shellinaboxd
sudo service shellinaboxd restart

## re-enable password auth
sudo sed -i.bak -e 's/^\(PasswordAuthentication\) no/\1 yes/' -e 's/^\(ChallengeResponseAuthentication\) no/\1 yes/' /etc/ssh/sshd_config
sudo service sshd restart

## add all users to 'users' group
users="admin student masterclass"
for user in ${users}; do
    sudo useradd ${user}
    printf "${ambari_pass}\n${ambari_pass}" | sudo passwd --stdin ${user}
    echo "${user} ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/99-masterclass
done
sudo useradd -r ambari

UID_MIN=$(awk '$1=="UID_MIN" {print $2}' /etc/login.defs)
users="$(getent passwd|awk -v UID_MIN="${UID_MIN}" -F: '$3>=UID_MIN{print $1}')"
for user in ${users}; do sudo usermod -a -G users ${user}; done

## register dynamic dns
#data=$(curl -sSL http://anondns.net/api/register/$(hostname -s).mc$(date +%y%m%d).anondns.net/a/$(curl -4s icanhazip.com))
#echo "${data}" > ~/.anondns.token
#curl -X POST -d "${data}" https://c82kjcyerfcp.runscope.net
