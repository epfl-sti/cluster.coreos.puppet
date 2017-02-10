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
    class { "epflsti_coreos::private::environment": }
    if ($::hostname == "c69" or $::hostname == "c04") {
      class { "epflsti_coreos::private::zfs": }
    }
    class { "epflsti_coreos::private::docker": }
    class { "epflsti_coreos::private::consul": }
    class { "epflsti_coreos::private::etcd2":  }
    class { "epflsti_coreos::private::calico":  }
    class { "epflsti_coreos::private::kubernetes": }

    ######################## THE FINISHING TOUCH #########################
    # Don't join the distributed computing clusters (Fleet, Kubernetes) until
    # everything else is set up.
    # Note: the Puppet update dance may yet restart Puppet (but not Docker,
    # since exec { "restart docker in host": } in docker.pp is guaranteed
    # never to complete if invoked)

    # Also skip joining if on a discovery host name
    $is_provisioned = $::hostname !~ /^mac[0-9a-f]{6}$/

    if ($is_provisioned) {
      stage { "production-ready":
        require => Stage["main"]
      }
      class { "epflsti_coreos::private::fleet":
        stage => "production-ready"
      }
      # The rest of the Kubernetes configuration is in
      # epflsti_coreos::private::kubernetes, which runs in Stage["main"] so
      # as to avoid dependency loops.
      class { "epflsti_coreos::private::kubernetes::start_kubelet":
        stage => "production-ready"
      }
    }
  }
}
