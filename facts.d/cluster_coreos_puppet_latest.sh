#!/bin/sh
#
# Find latest version of Docker image cluster.coreos.puppet in the local
# Docker registry, and report it as the $::cluster_coreos_puppet_latest
# fact.
#
# Note: for some reason, facter --puppet won't run this script (but
# Puppet does)

registry_hostname_short=docker-registry
registry_port=5000
puppet_image_name=cluster.coreos.puppet

docker=/opt/root/usr/bin/docker

set -e

cluster_coreos_puppet_latest=$(${docker} images -q ${registry_hostname_short}.$(hostname -d):${registry_port}/${puppet_image_name})

echo cluster_coreos_puppet_latest="$cluster_coreos_puppet_latest"
