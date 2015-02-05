Tools for deploying clusters with Ambari
========================================

Purpose
-------

Automated some of the processes involved with deploying a cluster.

1st objective: single command to deploy a cluster with Ambari Recommendations, such that a blueprint is not needed.

Usage
-----

- Fetch to the Ambari Server:
  - `git clone https://github.com/seanorama/ambari-bootstrap.git; cd ambari-bootstrap/deploy`
  - or `curl -ssLO https://github.com/seanorama/ambari-bootstrap/archive/master.zip; unzip master.zip; cd ambari-bootstrap-master/deploy`

- Deploy Hortonworks Data Platform from Ambari Recommendations (no blueprint required):
  - bash ./deploy-recommended-cluster.py

Configuration
-------------

Several options can be passed through as environment variables:

  - 

Contacts
--------

* Sean Roberts
  - @seanorama
  - http://twitter.com/seano
