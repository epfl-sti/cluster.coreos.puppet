# Class: epflsti_coreos::private::fleet
#
# Configure fleet
#
# This class is intended to be loaded on all nodes.
#
# === Global variables:
#
# [*ups_hosts*]
#   A YAML-encoded list of short hostnames that have uninterruptible power plugged into them.
#
# [*etcd_region*]
#   The "region=" metadata for fleet
#
# === Actions:
#
# * Alter the fleet configuration to set its public IP and metadata
# 
# === Bootstrapping:
#
# This class is bootstrap-aware.

class epflsti_coreos::private::fleet() {
    $ups_host_list = parseyaml($::ups_hosts)
    $region = $::etcd_region
    validate_array($ups_host_list)
    validate_string($region)

    $has_ups = member($ups_host_list, $::hostname)

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
