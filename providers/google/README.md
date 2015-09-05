# General notes for my Google account

________________________________________________________________________

## General notes:

## whitelist IPs
```
ip=$(curl -4 icanhazip.com)
network="hdp-partner-workshop"
## or manually specify your IP:
#ip=1.2.3.4
gcloud compute --project "siq-haas" firewall-rules create \
    "source-$(echo ${ip} | tr '.' '-')"   --allow tcp,udp \
    --network "${network}" --source-ranges "${ip}/32"
```

## snapshot the active directory server
```
server="activedirectory"
gcloud compute disks snapshot "${server}" \
    --zone "europe-west1-b" --snapshot-names "partner-${server}-snapshot-$(date +%Y%m%d-%H%M%S)"
```

________________________________________________________________________

## Deploying HDP

CloudBreak or bdutil are the preferred tools for deploying on Google Cloud.

But for test & workshops I deploy directly using the commands below

### Setup account: these are only needed once

- Set defaults for gcloud command-line:

```
gcloud config set project siq-haas
gcloud config set compute/zone europe-west1-b
```

- Create network & instance-group:

```
network="hdp-partner-workshop"x 
gcloud compute --project "siq-haas" networks create "${network}" --range "10.240.0.0/16"

gcloud preview --project "siq-haas" instance-groups --zone "europe-west1-b" \
    create "${network}" --network "${network}"
```

### Deploying many single node clusters for test/labs

I was deploying a large number of hosts for each class. I did so with a messy set of bash & pdsh commands.

```
export lab_count=1
export lab_first=904
export lab_prefix=mc-lab
git clone https://github.com/seanorama/ambari-bootstrap /tmp/ambari-bootstrap
source "/tmp/ambari-bootstrap/providers/google/create-google-hosts.sh"
create=true "/tmp/ambari-bootstrap/providers/google/create-google-hosts.sh"
```

- Then you can check the hosts with:

```
command="echo OK"; pdsh -w ${hosts_all} "${command}"
```

- Or execute a list of commands:

```
read -r -d '' command <<EOF

uptime
curl -sSL https://raw.githubusercontent.com/seanorama/masterclass/master/security/setup.sh | bash
whoami

EOF
pdsh -w ${hosts_all} "${command}"
```

