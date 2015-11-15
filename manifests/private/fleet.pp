# Class: epflsti_coreos::private::fleet
#
# Configure fleet
#
# This class is intended to be loaded on all nodes.
#
# === Parameters:
#
# [*ups_hosts*]
#   A list of short hostnames that have uninterruptible power plugged into them.
#
# [*region*]
#   The "region=" metadata for fleet
#
# === Actions:
#
# * Alter the fleet configuration to set its public IP and metadata
# 
# === Bootstrapping:
#
# This class is bootstrap-aware.

class epflsti_coreos::private::fleet(
  $ups_hosts = [],
  $region = undef
) {
    validate_array($ups_hosts)
    validate_string($etcd_region)

    $has_ups = member($ups_hosts, $::hostname)

    include ::epflsti_coreos::private::systemd
    systemd::unit { "fleet.service":
      enable => true,
      start => true
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
