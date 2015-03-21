Tools for deploying clusters with Ambari
========================================

Purpose
-------

Deploy a cluster with Ambari using Ambari Recommendations. **No blueprint required!**

Requirements
----

- python-argparse. On RedHat/CentOS: `yum install python-argparse`
- bash

Usage
-----

- Fetch to the Ambari Server which already has Ambari Agents registered:
  - `git clone https://github.com/seanorama/ambari-bootstrap.git; cd ambari-bootstrap/deploy`
  - or `curl -ssLO https://github.com/seanorama/ambari-bootstrap/archive/master.zip; unzip master.zip; cd ambari-bootstrap-master/deploy`

- Deploy Hortonworks Data Platform _(no blueprint required)_:
  - `bash ./deploy-recommended-cluster.bash`

- Deploy HDP with minimal services:

  ```
  export ambari_services="HDFS MAPREDUCE2 YARN ZOOKEEPER"
  bash ./deploy-recommended-cluster.bash
  ```
  
  - The default services are: `FALCON FLUME GANGLIA HBASE HDFS HIVE KAFKA KERBEROS MAPREDUCE2
    NAGIOS OOZIE PIG SLIDER SQOOP STORM TEZ YARN ZOOKEEPER`
  - 'ambari_services' and other configuration overrides can be seen in in './deploy-recommended-cluster.bash'

What?
-----

The basic process:

1. Ambari 1.7+ includeds a recommendation API: `/api/v1/stacks/HDP/versions/2.2/recommendations`
2. You make 2 POSTS to that:
  * `{ "recommend": "configurations", "hosts": [ "host1", "host2", ... ], "services": [ "HDFS", "YARN", ... ] }`
  * `{ "recommend": "host_groups",    "hosts": [ "host1", "host2", ... ], "services": [ "HDFS", "YARN", ... ] }`
3. That produces a blueprint & cluster template which you send to `/api/v1/blueprints` & `/api/v1/clusters` (as you would for any blueprint)
4. The 'services' section can be anything supported by the stack.
  * the available services are listed at: `/api/v1/stacks/STACKNAME/versions/STACKVERSION/services`
  * for reference, HDP 2.2 has: FALCON FLUME GANGLIA HBASE HDFS HIVE KAFKA KNOX MAPREDUCE2 NAGIOS OOZIE PIG SLIDER SQOOP STORM TEZ YARN ZOOKEEPER 

Blueprint recommendations currently has 2 bugs which this script works around by manipulating the JSON templates before submitting:

* The configuration for some services misses key values which will cause a cluster build to fail (nagios admin, hive credentials, and sometimes places zk weird or hive_metastore weird)
* Any configurations passed in the recommendation request are ignored. So a `configuration-custom.json` is merged to provide customer configuration.

Configuration
-------------

Several options can be passed through as environment variables:
  - TODO: Need document these
  - For now have a look at the variables set at the top of the bash file.

Contacts
--------

* Sean Roberts
  - @seanorama
  - http://twitter.com/seano
