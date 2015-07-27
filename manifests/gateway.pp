# Class: epflsti_coreos::gateway
#
# Configure the default route with Puppet on CoreOS hosts, EPFLSTI-style.
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
# [*gateway_vip*]
#   To be set only on the router; enable that virtual IP (VIP).
#   TODO: this should be moved to a heartbeat rig. This not made persistent
#   for that reason.
#
# === Actions:
#
# This module sets the default route and activates IPv4 forwarding on gateway
# nodes (those that have $external_address set).
class epflsti_coreos::gateway(
  $external_interface = "enp1s0f1",
  $external_address = undef,
  $external_gateway = undef,
  $external_netmask = undef,
  $gateway_vip = undef
) {
  if ($external_address) {
    validate_string($external_gateway, $external_netmask)
  }

  exec { "restart networkd in host":
    command => "/usr/bin/systemctl restart systemd-networkd.service",
    refreshonly => true
  }

  if ($external_address) {
    file { "/etc/systemd/50-${external_interface}-epflnet.network":
      ensure => "present",
      contents => template("50-epflnet.network.erb")
    } ~> Exec["restart networkd in host"]
    file { "/etc/systemd/40-ethbr4-nogateway.network":
      ensure => "link",
      target => "40-ethbr4-nogateway.opt-network"
    } ~> Exec["restart networkd in host"]

  } else {
    file { "/etc/systemd/40-ethbr4-nogateway.network":
      ensure => "absent"
    } ~> Exec["restart networkd in host"]
  }

  if ($gateway_vip) {
    exec { "Enable gateway VIP":
      path => $path,
      command => "/sbin/ip addr add ${gateway_vip}/24 dev ethbr4",
      unless => "/sbin/ip addr show |grep -qw ${gateway_vip}"
    } 
    exec { "Enable masquerading":
      path => $path,
      command => "/sbin/iptables -t nat -A POSTROUTING -o ${external_interface} -j MASQUERADE",
      unless => "/sbin/iptables -t nat -L -v| grep 'MASQUERADE.*${external_interface}'"
    } 
  } else {
    exec { "Disable gateway VIP":
      path => $path,
      command => "/sbin/ip addr del ${gateway_vip}/24",
      unless => "! /sbin/ip addr show | grep -qw ${gateway_vip}"
    } 
    exec { "Disable masquerading":
      path => $path,
      command => "/sbin/iptables -t nat -D POSTROUTING -o ${external_interface} -j MASQUERADE",
      unless => "! /sbin/iptables -t nat -L -v| grep 'MASQUERADE.*${external_interface}'"
    } 
  }
}
