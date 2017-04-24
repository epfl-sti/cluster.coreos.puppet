#!/bin/sh

calico_cni=/opt/root/opt/cni/bin/calico
calico_cni_version="$($calico_cni -v 2>/dev/null || echo undef)"
echo calico_cni_version=$(echo "$calico_cni_version"|sed 's/^v//')
