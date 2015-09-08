#!/usr/bin/env bash

mypass="${mypass:-BadPass#1}"

## details of my ad host
ad_host="${ad_host:-activedirectory.$(hostname -d)}"
ad_host_ip=$(ping -w 1 ${ad_host} | awk 'NR==1 {print $3}' | sed 's/[()]//g')
echo "${ad_host_ip} activedirectory.hortonworks.com ${ad_host} activedirectory" | sudo tee -a /etc/hosts

sudo yum makecache
sudo yum -y -q install git epel-release screen ntpd mlocate python-configobj bind-utils
sudo yum -y -q install shellinabox mosh tmux ack jq python-argparse python-pip
sudo pip install --upgrade pip
sudo pip install httpie

sudo chkconfig ntpd on
sudo service ntpd restart

## shell in a box, web based console on port 4200
sudo chkconfig shellinaboxd on
#sudo sed -i.bak 's/^\(OPTS=.*\):LOGIN/\1:SSH/' /etc/sysconfig/shellinaboxd
sudo service shellinaboxd restart

## re-enable password auth
sudo sed -i.bak -e 's/^\(PasswordAuthentication\) no/\1 yes/' -e 's/^\(ChallengeResponseAuthentication\) no/\1 yes/' /etc/ssh/sshd_config
sudo service sshd restart

## add all users to 'users' group
users="admin rangeradmin keyadmin"
for user in ${users}; do
    sudo useradd ${user}
    printf "${mypass}\n${mypass}" | sudo passwd --stdin ${user}
done
sudo useradd -r ambari

UID_MIN=$(awk '$1=="UID_MIN" {print $2}' /etc/login.defs)
users="$(getent passwd|awk -v UID_MIN="${UID_MIN}" -F: '$3>=UID_MIN{print $1}')"
for user in ${users}; do sudo usermod -a -G users ${user}; done

## register dynamic dns
data=$(curl -sSL http://anondns.net/api/register/$(hostname -s).mc$(date +%y%m%d).anondns.net/a/$(curl -4s icanhazip.com))
echo "${data}" > ~/.anondns.token
curl -X POST -d "${data}" https://c82kjcyerfcp.runscope.net

