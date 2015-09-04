# General notes for my Google account

## snapshot the active directory server
```
gcloud compute disks snapshot "activedirectory" \
    --zone "europe-west1-b" --snapshot-names "partner-activedirectory-snapshot-$(date +%Y%m%d-%H%M%S)"
```

## whitelist IPs
```
ip=$(curl -4 icanhazip.com)
## or manually specify your IP:
#ip=1.2.3.4
gcloud compute --project "siq-haas" firewall-rules create \
    "source-$(echo ${ip} | tr '.' '-')"   --allow tcp,udp \
    --network "hdp-partner-workshop" --source-ranges "${ip}/32"
```

##
