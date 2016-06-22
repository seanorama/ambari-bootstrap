#!/usr/bin/env bash

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"
source ${__dir}/../ambari_functions.sh
ambari_configs

sudo mkdir -p /opt/hadoop/samples
sudo chmod 777 /opt/hadoop/samples
cd /opt/hadoop/samples

dfs_cmd="sudo sudo -u hdfs hadoop fs"
dfs_cmd_admin="sudo sudo -u admin hadoop fs"

${dfs_cmd} -mkdir /public
${dfs_cmd} -mkdir -p /public/samples /public/secured/dir1
${dfs_cmd} -chmod -R 777 /public

## Sandbox data sets
curl -sSL -O https://raw.githubusercontent.com/abajwa-hw/security-workshops/master/data/sample_07.csv
curl -sSL -O https://raw.githubusercontent.com/abajwa-hw/security-workshops/master/data/sample_08.csv
${dfs_cmd_admin} -put sample_07.csv sample_08.csv /public/samples

cat > sample-populate.sql <<-'EOF'
CREATE TABLE `sample_07` (
`code` string ,
`description` string ,
`total_emp` int ,
`salary` int )
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TextFile;
LOAD DATA LOCAL INPATH '/opt/hadoop/samples/sample_07.csv' INTO TABLE sample_07;

CREATE TABLE `sample_08` (
`code` string ,
`description` string ,
`total_emp` int ,
`salary` int )
ROW FORMAT DELIMITED FIELDS TERMINATED BY '\t' STORED AS TextFile;
load data local inpath '/opt/hadoop/samples/sample_08.csv' into table sample_08;
EOF

beeline -n student -u jdbc:hive2://$(hostname -f):10000/default -f sample-populate.sql

## Trucking demo data sets
curl -sSL -O https://raw.githubusercontent.com/seanorama/ambari-bootstrap/master/extras/samples/Geolocation.zip
unzip Geolocation.zip
${dfs_cmd_admin} -put geolocation.csv trucks.csv /public/samples

## Trucking demo tables
cat > trucking.sql <<-'EOF'
CREATE TABLE geolocation_stage (truckid string, driverid string, event string, latitude double, longitude double, city string, state string, velocity bigint, event_ind bigint, idling_ind bigint)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

CREATE TABLE trucks_stage(driverid string, truckid string, model string, jun13_miles bigint, jun13_gas bigint, may13_miles bigint, may13_gas bigint, apr13_miles bigint, apr13_gas bigint, mar13_miles bigint, mar13_gas bigint, feb13_miles bigint, feb13_gas bigint, jan13_miles bigint, jan13_gas bigint, dec12_miles bigint, dec12_gas bigint, nov12_miles bigint, nov12_gas bigint, oct12_miles bigint, oct12_gas bigint, sep12_miles bigint, sep12_gas bigint, aug12_miles bigint, aug12_gas bigint, jul12_miles bigint, jul12_gas bigint, jun12_miles bigint, jun12_gas bigint,may12_miles bigint, may12_gas bigint, apr12_miles bigint, apr12_gas bigint, mar12_miles bigint, mar12_gas bigint, feb12_miles bigint, feb12_gas bigint, jan12_miles bigint, jan12_gas bigint, dec11_miles bigint,  dec11_gas bigint, nov11_miles bigint, nov11_gas bigint, oct11_miles bigint, oct11_gas bigint, sep11_miles bigint, sep11_gas bigint, aug11_miles bigint, aug11_gas bigint, jul11_miles bigint, jul11_gas bigint, jun11_miles bigint, jun11_gas bigint, may11_miles bigint, may11_gas bigint, apr11_miles bigint, apr11_gas bigint, mar11_miles bigint, mar11_gas bigint, feb11_miles bigint, feb11_gas bigint, jan11_miles bigint, jan11_gas bigint, dec10_miles bigint, dec10_gas bigint, nov10_miles bigint, nov10_gas bigint, oct10_miles bigint, oct10_gas bigint, sep10_miles bigint, sep10_gas bigint, aug10_miles bigint, aug10_gas bigint, jul10_miles bigint, jul10_gas bigint, jun10_miles bigint, jun10_gas bigint, may10_miles bigint, may10_gas bigint, apr10_miles bigint, apr10_gas bigint, mar10_miles bigint, mar10_gas bigint, feb10_miles bigint, feb10_gas bigint, jan10_miles bigint, jan10_gas bigint, dec09_miles bigint, dec09_gas bigint, nov09_miles bigint, nov09_gas bigint, oct09_miles bigint, oct09_gas bigint, sep09_miles bigint, sep09_gas bigint, aug09_miles bigint, aug09_gas bigint, jul09_miles bigint, jul09_gas bigint, jun09_miles bigint, jun09_gas bigint, may09_miles bigint, may09_gas bigint, apr09_miles bigint, apr09_gas bigint, mar09_miles bigint, mar09_gas bigint, feb09_miles bigint, feb09_gas bigint, jan09_miles bigint, jan09_gas bigint)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

LOAD DATA LOCAL INPATH '/opt/hadoop/samples/geolocation.csv' OVERWRITE INTO TABLE geolocation_stage;
LOAD DATA LOCAL INPATH '/opt/hadoop/samples/trucks.csv' OVERWRITE INTO TABLE trucks_stage;

CREATE TABLE geolocation STORED AS ORC AS SELECT * FROM geolocation_stage;
CREATE TABLE trucks STORED AS ORC AS SELECT * FROM trucks_stage;

DROP TABLE geolocation_stage;
DROP TABLE trucks_stage;
EOF

beeline -n student -u jdbc:hive2://$(hostname -f):10000/default -f trucking.sql

exit

beeline -n student -u jdbc:hive2://$(hostname -f):10000/default -e \
"CREATE TABLE truck_mileage STORED AS ORC AS
  SELECT truckid, driverid, rdate, miles, gas, miles / gas mpg
  FROM trucks
  LATERAL VIEW stack( 54, 'jun13',jun13_miles,jun13_gas,'may13',may13_miles,may13_gas,'apr13',apr13_miles,apr13_gas,'mar13',mar13_miles,mar13_gas,'feb13',feb13_miles,feb13_gas,'jan13',jan13_miles,jan13_gas,'dec12',dec12_miles,dec12_gas,'nov12',nov12_miles,nov12_gas,'oct12',oct12_miles,oct12_gas,'sep12',sep12_miles,sep12_gas,'aug12',aug12_miles,aug12_gas,'jul12',jul12_miles,jul12_gas,'jun12',jun12_miles,jun12_gas,'may12',may12_miles,may12_gas,'apr12',apr12_miles,apr12_gas,'mar12',mar12_miles,mar12_gas,'feb12',feb12_miles,feb12_gas,'jan12',jan12_miles,jan12_gas,'dec11',dec11_miles,dec11_gas,'nov11',nov11_miles,nov11_gas,'oct11',oct11_miles,oct11_gas,'sep11',sep11_miles,sep11_gas,'aug11',aug11_miles,aug11_gas,'jul11',jul11_miles,jul11_gas,'jun11',jun11_miles,jun11_gas,'may11',may11_miles,may11_gas,'apr11',apr11_miles,apr11_gas,'mar11',mar11_miles,mar11_gas,'feb11',feb11_miles,feb11_gas,'jan11',jan11_miles,jan11_gas,'dec10',dec10_miles,dec10_gas,'nov10',nov10_miles,nov10_gas,'oct10',oct10_miles,oct10_gas,'sep10',sep10_miles,sep10_gas,'aug10',aug10_miles,aug10_gas,'jul10',jul10_miles,jul10_gas,'jun10',jun10_miles,jun10_gas,'may10',may10_miles,may10_gas,'apr10',apr10_miles,apr10_gas,'mar10',mar10_miles,mar10_gas,'feb10',feb10_miles,feb10_gas,'jan10',jan10_miles,jan10_gas,'dec09',dec09_miles,dec09_gas,'nov09',nov09_miles,nov09_gas,'oct09',oct09_miles,oct09_gas,'sep09',sep09_miles,sep09_gas,'aug09',aug09_miles,aug09_gas,'jul09',jul09_miles,jul09_gas,'jun09',jun09_miles,jun09_gas,'may09',may09_miles,may09_gas,'apr09',apr09_miles,apr09_gas,'mar09',mar09_miles,mar09_gas,'feb09',feb09_miles,feb09_gas,'jan09',jan09_miles,jan09_gas ) 
  dummyalias AS rdate, miles, gas;"

beeline -n student -u jdbc:hive2://$(hostname -f):10000/default -e \
"CREATE TABLE DriverMileage
STORED AS ORC
AS
SELECT driverid, sum(miles) totmiles 
FROM truck_mileage 
GROUP BY driverid;"

beeline -n student -u jdbc:hive2://$(hostname -f):10000/default -e \
"CREATE TABLE riskfactor (
driverid string, 
events bigint, 
totmiles bigint, 
riskfactor float) 
STORED AS ORC;"
