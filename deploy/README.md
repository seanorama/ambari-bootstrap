Tools for deploying clusters with Ambari
========================================

Purposes
-------

- Deploy an HDP cluster without writing an Ambari Blueprint.
- Generate Ambari Blueprints and/or configuration recommendations as a base for crafting your own Blueprints.

Requirements
----

- bash
- python-argparse. On RedHat/CentOS: `yum install python-argparse`
- Ambari Server with registered Ambari Agents
  - [ambari-bootstrap can do this if needed](https://github.com/seanorama/ambari-bootstrap#i-want-to-install-ambari--then-deploy-hdp-using-blueprints)


Usage
-----

- Fetch the package:
  - `git clone https://github.com/seanorama/ambari-bootstrap.git; cd ambari-bootstrap/deploy`
  - or `curl -ssLO https://github.com/seanorama/ambari-bootstrap/archive/master.zip; unzip master.zip; cd ambari-bootstrap-master/deploy`

- Deploy Hortonworks Data Platform _(no blueprint required)_:
  - This [will deploy all services](https://github.com/seanorama/ambari-bootstrap/blob/master/deploy/deploy-recommended-cluster.bash#L12-L14) by default!
  - `./deploy-recommended-cluster.bash`

Configuration
-------------

It reads a few environment variables as overrides:
  - Services to deploy: `export ambari_services="HDFS MAPREDUCE2 YARN PIG"`
  - Generate blueprint but do not deploy: `export deploy=false`
  - Ambari Agent host count check:
    - Don't deploy unless there are exactly 5 hosts registered: `export host_count=5`
    - Continue immediately with whatever hosts are registered: `export host_count=skip`
  - see [deploy-recommend-cluster.bash](deploy-recommended-cluster.bash) for a few more options (such as hostname & credentials).
  
Example to generate a blueprint with minimal services, but not deploy the cluster:

  ```
export ambari_services="HDFS MAPREDUCE2 YARN ZOOKEEPER PIG"
export deploy=false
./deploy-recommended-cluster.bash
  ```

How is this possible?
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


Contacts
--------

* Sean Roberts
  - @seanorama
  - http://twitter.com/seano
