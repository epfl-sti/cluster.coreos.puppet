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
#   The fixed, presumably publicly routable IPv4 address that this
#   host should respond to. If undef, $external_interface,
#   $external_gateway and $external_netmask are ignored.
#
# [*external_interface*]
#   The physical that should have address $external_address.
#
# [*external_gateway*]
#   IP address of the network gateway, as seen from the internal network
#
# [*external_netmask*]
#   The netmask for the external network.
#
# [*is_gateway*]
#   True iff this host should act as the gateway for the internal network
#   (by setting up a gateway alias IP address at $::gateway_vip, and masquerading
#   in iptables).
#   TODO: this should be moved to a heartbeat rig. This not made persistent
#   for that reason.
#
# === Global Variables:
#
# [*$::gateway_vip*]
#   The IP address to use to set up the gateway if ${is_gateway} is true
#
# === Actions:
#
# This module sets the default route and activates IPv4 forwarding on gateway
# nodes (those that have $external_address set).
class epflsti_coreos::gateway(
  $external_address = undef,
  $external_interface = "enp1s0f1",
  $external_gateway = undef,
  $external_netmask = undef,
  $is_gateway = undef
) {
  if ($external_address) {
    validate_string($external_gateway, $external_netmask)
  }

  exec { "restart networkd in host":
    command => "/usr/bin/systemctl restart systemd-networkd.service",
    refreshonly => true
  }

  if ($external_address) {
    file { "/etc/systemd/network/50-${external_interface}-epflnet.network":
      ensure => "present",
      content => template("epflsti_coreos/50-epflnet.network.erb")
    } ~> Exec["restart networkd in host"]
    file { "/etc/systemd/network/40-ethbr4-nogateway.network":
      ensure => "link",
      target => "40-ethbr4-nogateway.opt-network"
    } ~> Exec["restart networkd in host"]
    exec { "Disable default route through ethbr4":
      command => "/sbin/ip route del default dev ethbr4",
      onlyif => "/sbin/ip route show dev ethbr4 | grep -q ^default"
    }
  } else {
    file { ["/etc/systemd/network/40-ethbr4-nogateway.network",
            "/etc/systemd/network/50-${external_interface}-epflnet.network"]:
      ensure => "absent"
    } ~> Exec["restart networkd in host"]
    exec { "Flush addresses on ${external_interface}":
      command => "/sbin/ip addr flush dev ${external_interface}",
      onlyif => "/sbin/ip addr show dev ${external_interface} | grep -q inet"
    }
    exec { "Disable default route through ${external_interface}":
      command => "/sbin/ip route del default dev ${external_interface}",
      onlyif => "/sbin/ip route show dev ${external_interface} | grep -q ^default"
    }
  }

  if ($is_gateway) {
    exec { "Enable gateway VIP":
      path => $path,
      command => "/sbin/ip addr add ${::gateway_vip}/24 dev ethbr4",
      unless => "/sbin/ip addr show |grep -qw ${::gateway_vip}"
    } 
    exec { "Enable masquerading":
      path => $path,
      command => "/sbin/iptables -t nat -A POSTROUTING -o ${external_interface} -j MASQUERADE",
      unless => "/sbin/iptables -t nat -L -v| grep 'MASQUERADE.*${external_interface}'"
    } 
  } else {
    exec { "Disable gateway VIP":
      path => $path,
      command => "/sbin/ip addr del ${::gateway_vip}/24 dev ethbr4",
      onlyif => "/sbin/ip addr show | grep -qw ${::gateway_vip}"
    } 
    exec { "Disable masquerading":
      path => $path,
      command => "/sbin/iptables -t nat -D POSTROUTING -o ${external_interface} -j MASQUERADE",
      onlyif => "/sbin/iptables -t nat -L -v| grep 'MASQUERADE.*${external_interface}'"
    } 
  }
}
