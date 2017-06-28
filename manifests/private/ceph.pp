# Class: epflsti_coreos::private::ceph
#
# Configure a ceph MON quorum and OSD cluster wide
#
# === Actions:
#
# * Run the official ceph Docker image on all nodes; quorum members
#   are also MON.
#
# === Parameters:
#
# [*enabled*]
#    Whether to enable or disable Ceph. Set to false for one cycle of Puppet
#    in order to "un-Ceph" a former quorum node.
#
# [*rootpath*]
#    Where in the Puppet-agent Docker container, the host root is
#    mounted
#
# [*quorum_members*]
#   A YAML-encoded dict associating quorum member names with their
#   IP address.
#
# [*is_mon*]
#   Whether we want a MON on this node. By default, use the same quorum
#   nodes as all the etcd quorum
#
# [*is_osd*]
#   Whether we want an OSD on this node. By default, settle on nodes that
#   have two physical disks.
#
# === Global Variables:
#
# [*$::ipv4_network*]
#   The CIDR network/netmask for the internal addresses of nodes
#
# [*$::ceph_fsid*]
#   The FSID for the Ceph cluster.
#
# [*cluster_owner*]
#   The prefix for all tasks run by the cluster owner
#
class epflsti_coreos::private::ceph(
  $enabled = true,
  $rootpath = $epflsti_coreos::private::params::rootpath,
  $quorum_members = parseyaml($::quorum_members_yaml),
  $is_osd = "2" == inline_template("<%= @blockdevices.split(',').length %>"),
  $is_mon = undef
) inherits epflsti_coreos::private::params {
  if ($is_mon != undef) {
    $_is_mon = $is_mon
  } else {
    $_is_mon = !empty(intersection([$::ipaddress], values($quorum_members)))
  }

  if ($_is_mon) {
    $flavor = "mon"
  } elsif ($is_osd) {
    $flavor = "osd"
  }
  epflsti_coreos::private::comfort::alias {"ceph":
    value => inline_template('docker exec -it <%= @cluster_owner %>.ceph_<%= @flavor %>.service ceph ')
  }

  file { ["${rootpath}/var/lib/ceph", "${rootpath}/etc/ceph"]:
    ensure => "directory"
  }

  $_ceph_config_file = "${rootpath}/etc/ceph/ceph.conf"
  file { $_ceph_config_file:
      content => inline_template("[global]
fsid = ${::ceph_fsid}
mon initial members = <%= @quorum_members.keys.join(\" \") %>
osd journal size = 100
ms_bind_ipv6 = true
mon host = <%= @quorum_members.values.join(\" \") %>
public network = ${::ipv4_network}
cluster network = ${::ipv4_network}
auth cluster required = none
auth service required = none
auth client required = none
auth supported = none
")
  }

  $_mon_service_name = "${::cluster_owner}.ceph_mon.service"
  if ! $_is_mon {
    systemd::unit { $_mon_service_name:
      ensure => "absent",
      enable => false,
      start => false
    }
  } else {
    systemd::unit { $_mon_service_name:
      content => inline_template('#
[Unit]
Description=Ceph Monitor
After=docker.service

[Service]
EnvironmentFile=/etc/environment
ExecStartPre=-/usr/bin/docker kill %p.service
ExecStart=/usr/bin/docker run --rm --name %p.service --net=host -v /var/lib/ceph:/var/lib/ceph -v /etc/ceph:/etc/ceph -e MON_IP=<%= @ipaddress %> -e CEPH_PRIVATE_NETWORK=<%= @ipv4_network %> -e CEPH_PUBLIC_NETWORK=<%= @ipv4_network %> ceph/daemon mon
ExecStopPost=-/usr/bin/docker stop %p.service
ExecStopPost=-/usr/bin/docker rm %p.service
Restart=always
RestartSec=120s
TimeoutStartSec=120s
TimeoutStopSec=15s

'),
      enable => $enabled,
      start => $enabled
    } ->
    File[$_ceph_config_file] ~>
    exec { "restart ${_mon_service_name}":
      command => "systemctl restart ${_mon_service_name}",
      path => $::path,
      onlyif => "test -f ${_ceph_config_file} && systemctl is-active ${_mon_service_name}",
      refreshonly => true
    }
  }

  $_osd_service_name = "${::cluster_owner}.ceph_osd.service"
  if ! $is_osd {
    systemd::unit { $_osd_service_name:
      ensure => "absent",
      enable => false,
      start => false
    }
  } else {
    $_osd_journal = "/var/lib/ceph/journal/sdb"
    file { ["${rootpath}/var/lib/ceph/journal"]:
      ensure => "directory"
    } ->
    systemd::unit { $_osd_service_name:
      content => inline_template('#
[Unit]
Description=Ceph OSD
After=docker.service

[Service]
EnvironmentFile=/etc/environment
ExecStartPre=-/usr/bin/docker kill %p.service
ExecStartPre=-/usr/bin/docker run -v /dev:/dev -v /etc/ceph:/etc/ceph -v /var/lib/ceph:/var/lib/ceph --privileged  <%- -%>
  --entrypoint /usr/sbin/ceph-disk ceph/daemon prepare /dev/sdb <%= @_osd_journal %>
ExecStart=/usr/bin/docker run --rm --name %p.service --privileged --net=host -v /var/lib/ceph:/var/lib/ceph -v /etc/ceph:/etc/ceph <%- -%>
  -e OSD_DEVICE=/dev/sdb <%- -%>
  -e OSD_TYPE=activate <%- -%>
  -e OSD_JOURNAL=<%= @_osd_journal -%>
  ceph/daemon osd
ExecStopPost=-/usr/bin/docker stop %p.service
ExecStopPost=-/usr/bin/docker rm %p.service
Restart=always
RestartSec=120s
TimeoutStartSec=120s
TimeoutStopSec=15s

'),
      enable => $enabled,
      start => $enabled
    } ->
    File[$_ceph_config_file] ~>
    exec { "restart ${_osd_service_name}":
      command => "systemctl restart ${_osd_service_name}",
      path => $::path,
      onlyif => "test -f ${_ceph_config_file} && systemctl is-active ${_osd_service_name}",
      refreshonly => true
    }
  }
}
