#!/bin/sh

set -e

echo -n calicoctl_version=
/opt/root/opt/bin/calicoctl --version|sed 's/calicoctl version v//'
