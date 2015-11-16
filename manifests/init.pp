# Main class for EPFL-STI CoreOS clusters.
#
# This class is meant to be invoked directly by Foreman (or whatever
# top-level configuration mechanism is in use). Only a handful classes
# that cannot be configured in software (such as gateway), should
# also be invoked directly; all others are invoked from here.

class epflsti_coreos() {

  class { "epflsti_coreos::private::environment": }
  class { "epflsti_coreos::private::ssh": }
  class { "epflsti_coreos::private::puppet": }
  class { "epflsti_coreos::private::ipmi": }
  class { "epflsti_coreos::private::docker": }
  class { "epflsti_coreos::private::etcd2": }
  class { "epflsti_coreos::private::fleet":  }
  class { "epflsti_coreos::private::comfort": }

  # Networking setup - Best *not* done at production time!
  if ($::lifecycle_stage == "bootstrap") {
    class { "epflsti_coreos::private::networking": }
  }

  if ($::lifecycle_stage == "production") {
    # Add classes here that you don't care to test as part of
    # the bootstrap cycle.
    class { "epflsti_coreos::private::deis": }
  }
}
