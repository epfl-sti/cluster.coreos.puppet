# Main class for EPFL-STI CoreOS clusters.
#
# This class is meant to be invoked directly by Foreman (or whatever
# top-level configuration mechanism is in use). Only a handful classes
# that cannot be configured in software (such as gateway), should
# also be invoked directly; all others are invoked from here.

class epflsti_coreos(
  $etcd2_quorum_members = undef,
  $ups_hosts = [],
  $etcd_region = undef
  ) {
  validate_hash($etcd2_quorum_members)

  class { "epflsti_coreos::ssh": }
  class { "epflsti_coreos::puppet": }
  class { "epflsti_coreos::hostvars":
    ups_hosts => $ups_hosts,
    etcd_region => $etcd_region
  }

  # Networking setup - Best *not* done at production time!
  if ($::lifecycle_stage == "bootstrap") {
    class { "epflsti_coreos::private::networking": }
  }

  if ($::lifecycle_stage == "production") {
    class { "epflsti_coreos::ipmi": }
    class { "epflsti_coreos::private::etcd2":
      members => $etcd2_quorum_members
    }
  }
}
