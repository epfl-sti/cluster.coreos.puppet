# Class: epflsti_coreos::private::etcd2
#
# Configure etcd2 either as quorum member or proxy.
#
# This class is intended to be loaded on all nodes, with $members
# being the same value across the cluster. If $::ipaddress is
# found in $members, configure a quorum member (keeps a copy of all
# writes; can become master upon winning the election). If not,
# configure a proxy (only knows where the members and masters are;
# redirects most queries).
#
# === Actions:
#
# * Ensure that etcd2 is prepared as a quorum member or a
#   proxy, depending on $members. Note that a prepared quorum
#   member won't participate in the replication or elections,
#   unless and until you issue the appropriate "etcdctl member
#   add" command to inform the already existing members.
# * Restart failing proxies (poor man's monitoring feature)
#
# === Parameters:
#
# [*etcd2_quorum_members*]
#   A YAML-encoded dict associating etcd2 quorum member names with their
#   peer-advertised URLs.
#
# [*rootpath*]
#    Where in the Puppet-agent Docker container, the host root is
#    mounted
#
# === Variables:
#
# [*is_member*]
#    True iff this node is an etcd2 quorum member. Non-members
#    have a proxy etcd2 instead, so that "ordinary" etcd2 clients
#    need not know or care whether $is_member is true; rather,
#    this variable is for use for "quorum-only" tasks within Puppet.
#
# === See also:
#
# * paragraph "Add a New Member" in
#   https://github.com/coreos/etcd/blob/master/Documentation/runtime-configuration.md
# * https://github.com/coreos/etcd/blob/master/Documentation/admin_guide.md

class epflsti_coreos::private::etcd2(
  $rootpath = $epflsti_coreos::private::params::rootpath,
  $etcd2_quorum_members = $epflsti_coreos::private::params::etcd2_quorum_members
) inherits epflsti_coreos::private::params {
  include ::epflsti_coreos::private::systemd

  systemd::unit { "etcd.service":
    mask => true,
    start => false
  }

  systemd::unit { "etcd2.service":
    enable => true,
    start => true
  }

  $members = parseyaml($etcd2_quorum_members)
  validate_hash($members)

  $is_member = !empty(intersection([$::ipaddress], values($members)))

  file { "/etc/systemd/system/etcd2.service.d":
    ensure => "directory"
  } ->
  file { "/etc/systemd/system/etcd2.service.d/20-puppet.conf":
    ensure => "present",
    content => template("epflsti_coreos/20-etcd2.conf.erb")
  }

  $_restart_etcd2_clean = "systemctl stop etcd2.service && rm -rf ${rootpath}/var/lib/etcd2/proxy && systemctl start etcd2.service"

  exec { "reload systemd configuration and start etcd2":
    refreshonly => true,
    path => $::path,
    command => "systemctl daemon-reload && ${_restart_etcd2_clean}",
    subscribe => File["/etc/systemd/system/etcd2.service.d/20-puppet.conf"]
  }

  if (! $is_member) {
    # Poor man's monitoring for proxies, to work around
    # https://groups.google.com/d/msg/coreos-user/OuqvJIRAtho/VJ0NMo5BAgAJ
    exec { "restart desynched proxy":
      path => $::path,
      command => $_restart_etcd2_clean,
      onlyif => "/opt/root/bin/etcdctl cluster-health |grep 'zero endpoints'"
    }
  }
}
