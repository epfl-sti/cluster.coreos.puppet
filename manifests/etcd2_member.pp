# [*$::members*]
#   A dict associating etcd2 quorum member names with their peer-advertised URLs. Note:
#   etcd2 manages the quorum by itself; just changing the variable in
#   Foreman will *not* update the quorum. You need to follow
#   https://github.com/coreos/etcd/blob/master/Documentation/runtime-configuration.md,
#   of which Foreman only manages the second step of "Add a New
#   Member" (i.e. epflsti_coreos/20-etcd2.conf.erb ensures that --initial-cluster and
#   --initial-cluster-state are set correctly)
class epflsti_coreos::etcd2_member(
  $members = undef,
) {
  validate_hash($members)
  $members_as_text = join(values($members), ", ")
  if (empty(intersection([$::ipaddress_ethbr4], values($members)))) {
    fail("My IP address ${::ipaddress_ethbr4} is not configured in Puppet as a member (members are: ${members_as_text})")
  }
  file { "/etc/systemd/system/etcd2.service.d":
    ensure => "directory"
  } ->
  file { "/etc/systemd/system/etcd2.service.d/20-puppet.conf":
      ensure => "present",
      content => template("epflsti_coreos/20-etcd2.conf.erb")
  }
}
