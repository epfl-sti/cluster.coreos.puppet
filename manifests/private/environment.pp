# Class: epflsti_coreos::private::environment
#
# Configure /etc/environment
#
# This class is intended to be loaded on all nodes.
#
# === Parameters:
#
# [*has_ups*]
#   Whether this host has an Uninterruptible Power Supply
#
# [*rootpath*]
#    Where in the Puppet-agent Docker container, the host root is
#    mounted
#
# === Global Variables and Facts:
#
# See ../templates/environment.erb
#
# === Actions:
#
# * Create /etc/environment
# * Alter the fleet configuration to set its public IP and metadata
# 

class epflsti_coreos::private::environment(
  $has_ups = $epflsti_coreos::private::params::has_ups,
  $rootpath = $epflsti_coreos::private::params::rootpath
) inherits epflsti_coreos::private::params {
    # Maintain /etc/environment for unit files to source host-specific data from
    concat { "/etc/environment":
      path => "$rootpath/etc/environment",
      ensure => "present"
    }

    concat::fragment { "machine-dependent /etc/environment":
      target => "/etc/environment",
      order => '10',
      content => template("epflsti_coreos/environment.erb")
    }
}
