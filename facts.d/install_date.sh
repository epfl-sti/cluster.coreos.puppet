#!/bin/sh

set -e

install_date_epoch="$(stat -c '%Z' /opt/root/etc)"
echo install_date_epoch=$install_date_epoch
echo -n install_date_iso=
date -Iseconds -d @$install_date_epoch
