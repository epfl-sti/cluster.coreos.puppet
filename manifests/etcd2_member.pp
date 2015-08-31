# [*$::member_ips*]
#   A list of etcd2 quorum member IP addresses. Note:
#   etcd2 manages the quorum by itself; just changing the variable in
#   Foreman will *not* update the quorum. You need to follow
#   https://github.com/coreos/etcd/blob/master/Documentation/runtime-configuration.md,
#   of which Foreman only manages the second step of "Add a New
#   Member" (i.e. ensuring that --initial-cluster and
#   --initial-cluster-state are set correctly)
class epflsti_coreos::etcd2_member(
  $member_ips = undef,
) {
  validate_array($member_ips)
  if (empty(intersection([$::ipaddress_ethbr4], $member_ips))) {
    $member_ips_text = join($member_ips, ", ")
    fail("My IP address ${::ipaddress_ethbr4} is not configured in Puppet as a member (members are: ${member_ips_text})")
  }
}
