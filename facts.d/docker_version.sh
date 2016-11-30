#!/bin/sh

set -e

echo -n docker_version=
/opt/root/bin/docker --version | sed 's/Docker version //'
