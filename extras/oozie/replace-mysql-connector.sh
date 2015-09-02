#!/usr/bin/env bash

## THIS IS BAD
##  You should not touch files in /usr/hdp/current.
##  But hacking this for my little work with Sqoop on CentOS 6

version="5.1.36"
cd /tmp
curl -sSLO https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${version}.tar.gz
tar -xvf mysql-connector-java-${version}.tar.gz mysql-connector-java-${version}/mysql-connector-java-${version}-bin.jar
sudo mv mysql-connector-java-${version}/mysql-connector-java-${version}-bin.jar /usr/hdp/current/sqoop-server/lib/
sudo ln -sf /usr/hdp/current/sqoop-server/lib/mysql-connector-java-${version}-bin.jar /usr/hdp/current/sqoop-server/lib/mysql-connector-java.jar
