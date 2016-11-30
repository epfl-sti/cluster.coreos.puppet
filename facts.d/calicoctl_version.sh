#!/bin/sh

calicoctl=/opt/root/opt/bin/calicoctl
calicoctl_version="$($calicoctl --version 2>/dev/null|sed 's/calicoctl version v//')"

set -e

if [ -z "$calicoctl_version" ]; then
    calicoctl_version="$($calicoctl version)"
fi
echo calicoctl_version="$calicoctl_version"
