ambari-bootstrap
================

Collection of tools for bootstrapping Apache Ambari & deploying clusters

There are several tools:

  - 'ambari-bootstrap.sh' in this directory _(detail below)_
  - './deploy/' tools for deploying clusters after Ambari is installed on all hosts
  - './providers/' tools for various infrastructure/Cloud providers

ambari-bootstrap.sh
-------------------

### Purpose

Install & configure ambari-agent and/or ambari-server along with any pre-requisites.

Supports:
  - RedHat Enterprise Linux & CentOS 6
  - Planned support: Ubuntu. Welcoming contribution for any others

Requires:
  - 'root' or 'sudo' access
  - Internet access and functioning yum/apt repositories.

### Usage

- Simplest usage:
  - Fetch and then execute: `sudo sh ./ambari-bootstrap.sh`
  - Or, if you trust me: `curl -sSL https://s3-us-west-2.amazonaws.com/ambari-bootstrap/ambari-bootstrap-rhel6.sh | sudo -E sh`

- With options _(this example isntalls the agent, server, Oracle Java, and registers to an Ambari Server)_

  ```
  export install_ambari_agent=true
  export install_ambari_agent=true
  export java_provider=oracle
  export ambari_server=myserver.domain.local
  sudo sh ./ambari-bootstrap.sh
  ```

### Advanced usage


### Configuration

By default the script runs with these parameters:

  ```
  install_ambari_agent=true   ## Install the ambari-agent package.
  install_ambari_agent=false  ## Install the ambari-server package.
  java_provider=open          ## Which Java provider to use ('open' or 'oracle').
  ambari_server=localhost     ## Hostname of the Ambari Server.
                              ##   Allowing agents to register themselves with the
                              ##   server so you do not need to distribute SSH keys.
  ambari_version=1.7.0        ## Used to determine which repo/source to get packages from.
                              ##   Only tested with 1.7.0
  ambari_repo=...             ## The ambari.repo file to use for yum. See file for default
                              ##   and change at your own risk.
                              
### Contacts

- Sean Roberts
  - @seanorama
  - http://twitter.com/seano
