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

  class { "epflsti_coreos::private::environment":
    ups_hosts => $ups_hosts
  }
  class { "epflsti_coreos::private::ssh": }
  class { "epflsti_coreos::private::puppet": }
  class { "epflsti_coreos::private::ipmi": }
  class { "epflsti_coreos::private::docker": }
  class { "epflsti_coreos::private::etcd2":
      members => $etcd2_quorum_members
    }
  class { "epflsti_coreos::private::fleet":
    region => $etcd_region,
    ups_hosts => $ups_hosts
  }

  # Networking setup - Best *not* done at production time!
  if ($::lifecycle_stage == "bootstrap") {
    class { "epflsti_coreos::private::networking": }
  }

  if ($::lifecycle_stage == "production") {
    class { "epflsti_coreos::private::comfort": }
  }
}
