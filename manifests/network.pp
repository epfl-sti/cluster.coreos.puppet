# Class: epflsti_coreos::network
#
# Configure the CoreOS networking with Puppet, EPFLSTI-style.
#
# Puppet as a provisioning mechanism competes with CoreOS' own
# cloud-init, and therefore we use it only in specific cases - Here,
# for network configuration that ought to be independent from etcd for
# robustness reasons.
#
# === Parameters:
#
# [*external_address*]
#   The fixed, presumably publicly routable IPv4 address that this host should
#   respond to. If undef, $external_gateway and $external_netmask are ignored.
#
# [*external_gateway*]
#   IP address of the network gateway, as seen from the internal network
#
# [*external_netmask*]
#   The netmask for the external network.
#
# === Actions:
#
# This module sets the default route and activates IPv4 forwarding on gateway
# nodes (those that have $external_address set).
class epflsti_coreos::network(
  $external_address = undef,
  $external_gateway = undef,
  $external_netmask = undef,
) {
  if ($external_address) {
    validate_string($external_gateway, $external_netmask)
  }

  exec { "/usr/bin/systemctl restart systemd-networkd.service":
    alias => "restart networkd in host",
    refreshonly => true
  }

  if ($external_address) {
    file { "/etc/systemd/40-ethbr4-nogateway.network":
      ensure => "link",
      target => "40-ethbr4-nogateway.opt-network"
    } ~> Exec["restart networkd in host"]
  } else {
    file { "/etc/systemd/40-ethbr4-nogateway.network":
      ensure => "absent"
    } ~> Exec["restart networkd in host"]
  }
}
