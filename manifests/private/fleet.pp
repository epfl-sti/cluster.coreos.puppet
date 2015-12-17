# Class: epflsti_coreos::private::fleet
#
# Configure fleet
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
# === Global variables:
#
# [*etcd_region*]
#   The "region=" metadata for fleet
#
# === Actions:
#
# * Alter the fleet configuration to set its public IP and metadata

class epflsti_coreos::private::fleet(
  $has_ups = $epflsti_coreos::private::params::has_ups,
  $rootpath = $epflsti_coreos::private::params::rootpath
) inherits epflsti_coreos::private::params {
    $etcd_region = $::etcd_region
    validate_string($etcd_region)

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
      refreshonly => true
    }
}
