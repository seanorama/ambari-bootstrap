#!/usr/bin/env bash

sudo yum -y install git
sudo git clone https://github.com/seanorama/ambari-bootstrap /opt/ambari-bootstrap
sudo chmod -R g+rw /opt/ambari-bootstrap
sudo chown -R ${USER}:users /opt/ambari-bootstrap
ln -s /opt/ambari-bootstrap ~/

