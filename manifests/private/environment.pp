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
    file { "$rootpath/etc/environment":
        ensure => "present",
        content => template("epflsti_coreos/environment.erb"),
    }
}
