#!/usr/bin/env bash

server=localhost
pass=admin

curl -u admin:${pass} \
  -H X-Requested-By:script \
  -X POST -d @blueprint.json \
  http://${server}:8080/api/v1/blueprints/single

curl -u admin:${pass} \
  -H X-Requested-By:script \
  -X POST -d @cluster.json \
  http://${server}:8080/api/v1/clusters/mycluster

