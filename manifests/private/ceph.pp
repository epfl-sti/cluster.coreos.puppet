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
# [*fsid*]
#    The Ceph FSID. Should be set to the "ceph_fsid" of the first node in
#    the cluster
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
# [*cluster_owner*]
#   The prefix for all tasks run by the cluster owner
#
# === Global Variables:
#
# [*$::ipv4_network*]
#   The CIDR network/netmask for the internal addresses of nodes
#   and masquerading.
#
# [*$::ceph_fsid*]
#   The FSID for the Ceph cluster.
#
class epflsti_coreos::private::ceph(
  $enabled = true,
  $rootpath = $epflsti_coreos::private::params::rootpath,
  $quorum_members = $epflsti_coreos::private::params::etcd2_quorum_members,
  $is_mon = !empty(intersection([$::ipaddress], values(parseyaml($quorum_members)))),
  $is_osd = "2" == inline_template("<%= $::blockdevices.split(',').length %=>")) inherits epflsti_coreos::private::params {
  $_ceph_mon_service = inline_template('#
[Unit]
Description=Ceph Monitor
After=docker.service

[Service]
EnvironmentFile=/etc/environment
ExecStartPre=-/usr/bin/docker kill %p.service
ExecStartPre=/usr/bin/mkdir -p /etc/ceph /var/lib/ceph/mon
ExecStart=/usr/bin/docker run --rm --name %p.service --net=host -v /var/lib/ceph:/var/lib/ceph -v /etc/ceph:/etc/ceph -e MON_IP=<%= @ipaddress %> -e CEPH_PRIVATE_NETWORK=<%= @ipv4_network %> -e CEPH_PUBLIC_NETWORK=<%= @ipv4_network %> ceph/daemon mon
ExecStopPost=-/usr/bin/docker stop %p.service
ExecStopPost=-/usr/bin/docker rm %p.service
Restart=always
RestartSec=120s
TimeoutStartSec=120s
TimeoutStopSec=15s

')
  if $is_mon {
    $_ceph_config_file = "${rootpath}/etc/ceph/ceph.conf"
    $_service_name = "${::cluster_owner}.ceph_mon.service"

    exec { "restart ${_service_name}":
      command => "systemctl restart ${_service_name}",
      path => $::path,
      onlyif => "test -f ${_ceph_config_file} && systemctl is-active ${_service_name}",
      refreshonly => true
    }

    ini_setting { "fsid in ceph.conf":
      ensure  => present,
      path    => $_ceph_config_file,
      section => 'global',
      setting => 'fsid',
      value   => $::ceph_fsid
    } ~> Exec["restart ${_service_name}"]
    ini_setting { "mon initial members in ceph.conf":
      ensure  => present,
      path    => $_ceph_config_file,
      section => 'global',
      setting => 'mon initial members',
      value   => inline_template("<%= YAML.load(@quorum_members).values.join(\" \") %>")
    } ~> Exec["restart ${_service_name}"]

    systemd::unit { $_service_name:
      content => $_ceph_mon_service,
      enable => $enabled,
      start => $enabled
    }
  }
}
