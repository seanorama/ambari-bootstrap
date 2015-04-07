#!/usr/bin/env bash

server=localhost
pass=admin

host=$(hostname -f)
sed -i "s/yourhostnamehere/${host}/" cluster.json

curl -u admin:${pass} \
  -H X-Requested-By:script \
  -X POST -d @blueprint.json \
  http://${server}:8080/api/v1/blueprints/single

curl -u admin:${pass} \
  -H X-Requested-By:script \
  -X POST -d @cluster.json \
  http://${server}:8080/api/v1/clusters/mycluster

