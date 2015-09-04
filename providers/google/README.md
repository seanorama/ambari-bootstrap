# General notes for my Google account

## snapshot the active directory server
gcloud compute disks snapshot "activedirectory" \
    --zone "europe-west1-b" --snapshot-names "partner-activedirectory-snapshot-$(date +%Y%m%d-%H%M%S)"
