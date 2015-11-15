# Main class for EPFL-STI CoreOS clusters.
#
# This class is meant to be invoked directly by Foreman (or whatever
# top-level configuration mechanism is in use). Only a handful classes
# that cannot be configured in software (such as gateway), should
# also be invoked directly; all others are invoked from here.

class epflsti_coreos() {
  class { "epflsti_coreos::ipmi": }
  class { "epflsti_coreos::ssh": }
  class { "epflsti_coreos::etcd2": }
  class { "epflsti_coreos::puppet": }
}
