#!/usr/bin/env bash

## installs Solr & Banana dashboards for Ranger
## - this is for demoing only!
## - TODO: separate solr install from ranger banana dashboard install

## code stolen from my friend Ali: https://github.com/abajwa-hw/security-workshops/raw/master/scripts/setup_solr_banana.sh

# options:
#    if no arguments passed, FQDN will be used as hostname to setup dashboard/view
#    if "publicip" is passed, the public ip address will be used as hostname to setup dashboard/view
#    otherwise the passed in value will be assumed to be the hostname to setup dashboard/view

set -e

arg=$1
solr_home=/opt/lucidworks-hdpsearch/solr
SOLR_RANGER_PORT=8983
#solr_home=/opt/solr
banana_home=/opt/banana-ranger
#banana_home=/opt/banana

echo "arg is $arg"

if [ ! -z "$arg" ]
then
	if [ "$arg" == "<arguments>" ]; then
		echo "Invalid argument: $arg"
		exit 1
    elif [ "$arg" == "publicip" ]
    then
        echo "Argument publicip passed in..detecting public ip"
        host=$(curl -4 icanhazip.com)
    else
        echo "Using $arg as hostname"
        host=$arg
    fi
else
    echo "No argument passed in. Using FQDN"
    host=$(hostname -f)
fi

#####Install and start Solr#######

sudo yum install -y lucidworks-hdpsearch

if [ ! -d "/opt/lucidworks-hdpsearch" ]
then
	echo "HDP Search did not install correctly or may have timed out. Run yum install -y lucidworks-hdpsearch and re-run this script"
	exit 1
fi

cd
curl -sSLO https://github.com/abajwa-hw/security-workshops/raw/master/scripts/ranger_solr_setup.zip
unzip ranger_solr_setup.zip
rm -rf __MACOSX
cd ranger_solr_setup

echo "SOLR_INSTALL=false" > install.properties   
echo "SOLR_INSTALL_FOLDER=/opt/lucidworks-hdpsearch/solr" >> install.properties   
echo "SOLR_RANGER_HOME=/opt/lucidworks-hdpsearch/solr/ranger_audit_server" >> install.properties   
echo "SOLR_RANGER_DATA_FOLDER=/opt/lucidworks-hdpsearch/solr/ranger_audit_server/data" >> install.properties   
echo "SOLR_RANGER_PORT=8983" >> install.properties   
echo "SOLR_MAX_MEM=512m" >> install.properties

sudo ./setup.sh
#sudo $solr_home/ranger_audit_server/scripts/start_solr.sh

#####Install and start Banana#######
sudo mkdir -p ${banana_home}
cd ${banana_home}
sudo git clone https://github.com/LucidWorks/banana.git
sudo mv banana latest


#####Setup Ranger dashboard#######

#change references to logstash_logs
sudo sed -i 's/logstash_logs/ranger_audits/g'  ${banana_home}/latest/src/config.js

#copy ranger audit dashboard json and replace sandbox.hortonworks.com with host where Solr is installed
sudo curl -sSL -o ${banana_home}/latest/src/app/dashboards/default.json https://raw.githubusercontent.com/abajwa-hw/security-workshops/master/scripts/default.json
sudo sed -i.bak -e "s/sandbox.hortonworks.com:6083/${host}:${SOLR_RANGER_PORT}/g" ${banana_home}/latest/src/app/dashboards/default.json

#clean any previous webapp compilations
sudo rm -f $banana_home/latest/build/banana*.war
sudo rm -f $solr_home/server/webapps/banana.war

#compile latest dashboard json
sudo yum install -y ant
sudo mkdir -p $banana_home/latest/build/
cd ${banana_home}/latest
sudo ant

sudo cp -f $banana_home/latest/build/banana*.war $solr_home/server/webapps/banana.war
sudo cp -f $banana_home/latest/jetty-contexts/banana-context.xml $solr_home/server/contexts/

sudo tee -a /opt/lucidworks-hdpsearch/solr/bin/solr.in.sh << EOF
#SOLR_MEMORY=512m
#ZK_HOST="$(hostname -f):2181"
SOLR_RANGER_HOME=/opt/lucidworks-hdpsearch/solr/ranger_audit_server
SOLR_HOME=/opt/lucidworks-hdpsearch/solr/ranger_audit_server
SOLR_PORT=${SOLR_RANGER_PORT}
#SOLR_MODE=solrcloud
EOF

sudo chown -R solr /opt/lucidworks-hdpsearch/solr/
sudo chkconfig --add solr
sudo chkconfig solr on
sudo service solr restart

#####Restart Solr#######
#sudo $solr_home/ranger_audit_server/scripts/start_solr.sh
#sudo sed -i.bak -e "s/\(SOLR_RANGER_HOME\)$/\1 -c -z $(hostname -f):2181/" ${solr_home}/ranger_audit_server/scripts/start_solr.sh
#printf "\n$solr_home/ranger_audit_server/scripts/start_solr.sh\n\n" | sudo tee -a /etc/rc.local



#####Setup iFrame view to open Banana webui in Ambari#######

if [ ! -f /etc/yum.repos.d/epel-apache-maven.repo ]; then
    sudo curl -sSL -o /etc/yum.repos.d/epel-apache-maven.repo https://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo
fi
sudo yum -y -q install apache-maven
cd /tmp
git clone https://github.com/abajwa-hw/iframe-view.git
sed -i.bak -e "s/iFrame View/Ranger Audits/g" \
    -e "s/IFRAME_VIEW/RANGER_AUDITS/g" iframe-view/src/main/resources/view.xml
sed -i.bak -e "s,sandbox.hortonworks.com:6080,${host}:${SOLR_RANGER_PORT}/banana,g" iframe-view/src/main/resources/index.html
sed -i.bak -e "s/iframe-view/rangeraudits-view/g" \
    -e "s/Ambari iFrame View/Ranger Audits View/g" iframe-view/pom.xml
mv iframe-view rangeraudits-view
cd rangeraudits-view
mvn clean package
sudo cp target/*.jar /var/lib/ambari-server/resources/views
#sudo service ambari-server restart
#sudo service ambari-agent restart
#sleep 10
echo 
echo ## Ambari will need to be restarted for the Ambari View to be available
