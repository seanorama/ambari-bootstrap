#!/usr/bin/env bash

# This script will grow the root file system on redhat/centos 6&7
#
# Tested on Google Compute VMs
#

yum -y install epel-release
yum makecache
yum -y install perl cloud-init cloud-initramfs-tools dracut-modules-growroot cloud-utils-growpart
rpm -qa kernel | perl -pe 's/^kernel-//' | xargs -I {} dracut -f /boot/initramfs-{}.img {}
#sleep 5
#reboot
