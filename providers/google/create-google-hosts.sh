#!/usr/bin/env bash

## How to use:
##   create=true ./creage-google-hosts.sh
## Advanced usage:
##   create=true lab_first=90 lab_count=5 lab_prefix=mc-test ./creage-google-hosts.sh
## Sourcing the variables but not creating:
##   source ./creage-google-hosts.sh

## magic, don't touch
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename ${__file} .sh)"

create=${create:-false}

export lab_prefix=${lab_prefix:-mc-lab}
lab_first=${lab_first:-1}
lab_count=${lab_count:-1}

create_hdp=${create_hdp:-true}
create_ipa=false

export run_dir="~/src/masterclass/run"
export labs=$(seq -w ${lab_first} $((lab_first+lab_count-1)))

## gcloud settings
export domain="europe-west1-b.siq-haas"
export ssh_user="student"
export PDSH_SSH_ARGS_APPEND="-q -l ${ssh_user} -i ${HOME}/.ssh/student.pri.key -o ConnectTimeout=5 -o CheckHostIP=no -o StrictHostKeyChecking=no -o RequestTTY=force"

## building host list
#mkdir -p "${run_dir}"
#export conf="${run_dir}/${lab_prefix}-$(date +%Y%m%d).conf"
export hosts_hdp=$(for lab in ${labs}; do printf "${lab_prefix}${lab}.${domain},"; done)
export hosts_all=${hosts_hdp}

function main() {
  echo "## Creating these hosts:"
  for host in $(echo ${hosts_all} | tr ',' '\n'); do printf "   %s\n" "${host}"; done
  read -p "Press [Enter] to continue. Ctrl-C to cancel."

  if [ "${create}" = true  ]; then
    for lab in ${labs}; do
      create_instance_hdp ${lab} &
    done
    wait
    sleep 10
    for lab in ${labs}; do
      add_to_group ${lab} &
    done
    wait
    sleep 120
    gcloud compute config-ssh
    read -r -d '' command <<EOF
sudo sed -i.bak "s/^\(inet_protocols = \)all/\1ipv4/" /etc/postfix/main.cf; sudo service postfix restart
curl -sSL https://raw.githubusercontent.com/seanorama/ambari-bootstrap/master/providers/growroot.sh | sudo bash; sudo reboot
EOF
    pdsh -w ${hosts_all} "${command}"
  else
    echo "## Not creating instances. Please execute with:"
    echo "create=true ./creage-google-hosts.sh"
  fi
}

function create_instance_hdp() {
  local lab=$1
  echo "## Creating ${lab_prefix}${lab}.${domain}:"
  gcloud compute --project "siq-haas" instances create \
    "${lab_prefix}${lab}" --boot-disk-device-name "${lab_prefix}${lab}" \
    --machine-type "n1-standard-8" --image centos-7 \
    --metadata-from-file sshKeys=${__dir}/metadata-sshkeys \
    --zone "europe-west1-b" --network "hdp-partner-workshop" \
    --maintenance-policy "MIGRATE" --tags "hdp-partner-workshop" \
    --boot-disk-type "pd-standard" --boot-disk-size 200GB  --no-scopes

}

function add_to_group() {
  local lab=$1
  gcloud preview --project "siq-haas" instance-groups --zone "europe-west1-b" \
    instances --group "hdp-partner-workshop" add "${lab_prefix}${lab}"
}

function create_instance_ipa() {
  gcloud compute --project "siq-haas" instances create \
    "${lab_prefix}${lab}-ipa" --boot-disk-device-name "${lab_prefix}${lab}-ipa" \
    --machine-type "n1-standard-1" --image centos-7 \
    --metadata-from-file sshKeys=${__dir}/metadata-sshkeys \
    --zone "europe-west1-b" --network "hdp-partner-workshop" \
    --maintenance-policy "MIGRATE" --tags "hdp-partner-workshop" \
    --boot-disk-type "pd-standard" --boot-disk-size 50GB  --no-scopes

  gcloud preview --project "siq-haas" instance-groups --zone "europe-west1-b" \
    instances --group "hdp-partner-workshop" add "${lab_prefix}${lab}-ipa"
}

####
## actually run the script
[[ $0 != "$BASH_SOURCE" ]] || main "$@"

