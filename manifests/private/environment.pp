# Class: epflsti_coreos::private::environment
#
# Configure /etc/environment
#
# This class is intended to be loaded on all nodes.
#
# === Parameters:
#
# [*ups_hosts*]
#   A list of short hostnames that have uninterruptible power plugged into them.
#
# === Actions:
#
# * Create /etc/environment
# * Alter the fleet configuration to set its public IP and metadata
# 

class epflsti_coreos::private::environment(
  $ups_hosts = []
) {
    validate_array($ups_hosts)

    $rootpath = "/opt/root"
    $has_ups = member($ups_hosts, $::hostname)

    # Maintain /etc/environment for unit files to source host-specific data from
    file { "$rootpath/etc/environment":
        ensure => "present",
        content => template("epflsti_coreos/environment.erb"),
    }
}
