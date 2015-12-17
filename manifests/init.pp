# Main class for EPFL-STI CoreOS clusters.
#
# This class is meant to be invoked directly by Foreman (or whatever
# top-level configuration mechanism is in use). Only a handful classes
# that cannot be configured in software (such as gateway), should
# also be invoked directly; all others are invoked from here.
#
# === Bootstrapping:
#
# Puppet runs once after the CoreOS install is done, but before the
# first reboot (see epflsti/cluster.coreos.install on GitHub). Only
# a few classes can run at that time; even fewer of these will consult
# $::lifecycle_stage to determine the current stage (these classes
# are called "bootstrap-aware" in their respective comments).
#
# After reboot, in order not to attract jobs on an incompletely configured
# machine, ensure that the fleet configuration happens last (using a
# Puppet "stage" object).
#
class epflsti_coreos() {

  ################### BOOTSTRAP: BEFORE REBOOT ##########################
  class { "epflsti_coreos::private::networking": }
  class { "epflsti_coreos::private::ssh_authorized_keys": }
  class { "epflsti_coreos::private::puppet": }
  # For the IPMI facts, and to (attempt to) set an IPMI password:
  class { "epflsti_coreos::private::ipmi": }
  # The .bash_history template has a special case for bootstrap time:
  class { "epflsti_coreos::private::comfort": }

  ######################## AFTER REBOOT #################################
  if ($::lifecycle_stage == "production") {
    # Add classes here that you don't care to test as part of
    # the bootstrap cycle.
    class { "epflsti_coreos::private::ssh":  }
    class { "epflsti_coreos::private::deis": }
    class { "epflsti_coreos::private::environment": }
    class { "epflsti_coreos::private::docker": }
    class { "epflsti_coreos::private::etcd2":  }

    ######################## THE FINISHING TOUCH #########################
    # Don't join the Fleet cluster until everything else is set up.
    stage { "production-ready":
      require => Stage["main"]
    }
    class { "epflsti_coreos::private::fleet":
      stage => "production-ready"
    }
  }
}
