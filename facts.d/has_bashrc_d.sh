#!/bin/sh

if grep -q "/etc/bash/bashrc.d" /opt/root/usr/share/bash/bashrc; then
    echo has_bashrc_d=true
else
    echo has_bashrc_d=false
fi

