# Class: epflsti_coreos::etcd2
#
# Configure etcd2 either as quorum member or proxy.
#
# This class is intended to be loaded on all nodes, with $members
# being the same value across the cluster. If $::ipaddress_eth4 is
# found in $members, configure a quorum member (keeps a copy of all
# writes; can become master upon winning the election). If not,
# configure a proxy (only knows where the members and masters are;
# redirects all queries).
#
# === Parameters:
#
# [*members*]
#   A dict associating etcd2 quorum member names with their
#   peer-advertised URLs.
#
# === Actions:
#
# This is CoreOS, so we can't install anything; we assume that the
# bootstrap mechanism took care of that, as well as systemctl
# enabl'ing etcd2.service. As an unwanted corollary, /run/whatever was
# probably created; delete it.
#
# etcd2 members manage their quorum by themselves; Puppet can only
# *prepare* a new quorum member (i.e. set --initial-cluster and
# --initial-cluster-state as per second step of paragraph "Add a New
# Member",
# https://github.com/coreos/etcd/blob/master/Documentation/runtime-configuration.md).
# The rest of that doc explains how to complete the change (by writing
# into the etcd2 data store, which causes the master to start sending
# replication data to the new quorum member).
class epflsti_coreos::etcd2(
  $members = undef,
) {
  validate_hash($members)
  $is_proxy = empty(intersection([$::ipaddress], values($members)))
  file { "/etc/systemd/system/etcd2.service.d":
    ensure => "directory"
  } ->
  file { "/etc/systemd/system/etcd2.service.d/20-puppet.conf":
    ensure => "present",
    content => template("epflsti_coreos/20-etcd2.conf.erb")
  } ~>
  exec { "reload systemd configuration and start etcd2":
    refreshonly => true,
    path => $::path,
    command => "systemctl daemon-reload && systemctl restart etcd2.service"
  }
}
