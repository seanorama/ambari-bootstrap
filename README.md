ambari-bootstrap
================

Collection of tools for bootstrapping Apache Ambari & deploying clusters

There are several tools:

  - [ambari-bootstrap.sh](#ambari-bootstrapsh) - script which installs & configures Ambari along with it's pre-requisites. 
  - ./deploy/ - tools to quickly deploy clusters using Ambari
  - ./providers/ - tools for various infrastructure/Cloud providers

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

- Quick start _(ambari-agent only)_:
  - Fetch and then execute: `sudo sh ./ambari-bootstrap.sh`
  - Or, if you trust me: `curl -sSL https://raw.githubusercontent.com/seanorama/ambari-bootstrap/master/ambari-bootstrap.sh | sudo -E sh`

- With options _(showing install of Ambari agent, server, Oracle Java, and registering to an Ambari Server such that SSH keys aren't required)_

  ```
  export install_ambari_agent=true
  export install_ambari_server=true
  export java_provider=oracle
  export ambari_server=myserver.domain.local
  sudo sh ./ambari-bootstrap.sh
  ```

### Configuration

By default the script runs with these parameters:

  ```
  install_ambari_agent=true   ## Install the ambari-agent package.
  install_ambari_server=false ## Install the ambari-server package.
  java_provider=open          ## Which Java provider to use ('open' or 'oracle').
  ambari_server=localhost     ## Hostname of the Ambari Server.
                              ##   Allowing agents to register themselves with the
                              ##   server so you do not need to distribute SSH keys.
  ambari_version=1.7.0        ## Used to determine which repo/source to get packages from.
                              ##   Only tested with 1.7.0
  ambari_repo=...             ## The ambari.repo file to use for yum. See file for default
                              ##   and change at your own risk.
  ```

### Questions

#### I need to run this against a large number of hosts

There are a few options:

  a. If the servers are deployed through automation (such as with CloudProviders), you can include it in that orchestration. See ./providers/aws/ for an example.
  b. Pass the script to the servers a distributed ssh tool, such as pdsh. You could do this directly with SSH but ‘pdsh’ is more efficient.

  ```
  bootstrap_url=https://raw.githubusercontent.com/seanorama/ambari-bootstrap/master/ambari-bootstrap.sh
  ambari_server=p-workshop-ops01.cloud.hortonworks.com  ## this is the internal hostname of the ambari_server. Likely different than the host you will SSH too.

  ## install the ambari-server
  pdsh -w user@p-workshop-ops01.cloud.hortonworks.com "curl -sSL ${bootstrap_url} | install_ambari_server=true sh"

  ## install to all other nodes. See ‘man pdsh’ for the various ways you can specify hosts.
  pdsh -w p-workshop-ops0[2-4].cloud.hortonworks.com "curl -sSL ${bootstrap_url} | ambari_server=${ambari_server} sh"
  ```

#### I want to install Ambari & then deploy HDP using blueprints

After deploying the server & agents, you can quickly deploy HDP using Ambari Blueprints. See more in [./api-examples/](./api-examples/).

Alternatively, use the script from [./deploy/](./deploy/) to generate an Ambari Blueprint and deploy the cluster.

For example, this will deploy to a single node & then deploy with all HDP services which are supported by Ambari Blueprints.

  ```
  yum -y install git python-argparse
  git clone https://github.com/seanorama/ambari-bootstrap
  cd ambari-bootstrap
  export install_ambari_server=true
  ./ambari-bootstrap.sh
  cd deploy
  bash ./deploy-recommended-cluster.bash
  ```

If deploying to multiple nodes, install to all of the agent machines 1st, as described earlier, and then run the above on the server.

### Contacts

- http://github.com/seanorama/ambari-bootstrap/issues

- Sean Roberts
  - http://github.com/seanorama
  - http://twitter.com/seano
