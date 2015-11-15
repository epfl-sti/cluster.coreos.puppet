# Configure things that change depending on the host.
#
# This class is intended to be loaded on all nodes.
#
# === Parameters:
#
# [*ups_hosts*]
#   A list of short hostnames that have uninterruptible power plugged into them.
#
# [*etcd_region*]
#   The "region=" metadata for fleet
#
# === Actions:
#
# * Create /etc/environment
# * Alter the fleet configuration to set its public IP and metadata
# 

class epflsti_coreos::private::hostvars(
  $ups_hosts = [],
  $etcd_region = undef
) {
    validate_array($ups_hosts)
    validate_string($etcd_region)

    $rootpath = "/opt/root"
    $has_ups = member($ups_hosts, $::hostname)

    # Maintain /etc/environment for unit files to source host-specific data from
    file { "$rootpath/etc/environment":
        ensure => "present",
        content => template("epflsti_coreos/environment.erb"),
    }

    file { "$rootpath/etc/systemd/system/fleet.service.d":
      ensure => "directory"
    } ->
    file { "$rootpath/etc/systemd/system/fleet.service.d/50-puppet.conf":
      ensure => "present",
      content => template("epflsti_coreos/fleet-environment.conf.erb")
    } ~>
    exec { "restart fleetd":
      command => "/usr/bin/systemctl daemon-reload && /usr/bin/systemctl restart fleet.service",
      refreshonly => true,
      unless => "/usr/bin/test '${::lifecycle_stage}' = bootstrap"
    }
}
