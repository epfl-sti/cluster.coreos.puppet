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
# === Parameters:
#
# [*members*]
#   A dict associating etcd2 quorum member names with their
#   peer-advertised URLs.
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
# === See also:
#
# * paragraph "Add a New Member" in
#   https://github.com/coreos/etcd/blob/master/Documentation/runtime-configuration.md
# * https://github.com/coreos/etcd/blob/master/Documentation/admin_guide.md

class epflsti_coreos::private::etcd2(
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

  if ($is_proxy) {
    # Poor man's monitoring for proxies, to work around
    # https://groups.google.com/d/msg/coreos-user/OuqvJIRAtho/VJ0NMo5BAgAJ
    exec { "restart desynched proxy":
      path => $::path,
      command => "systemctl stop etcd2.service && rm -rf /opt/root/var/lib/etcd2/proxy && systemctl start etcd2.service",
      onlyif => "/opt/root/bin/etcdctl cluster-health |grep 'zero endpoints'"
    }
  }
}
