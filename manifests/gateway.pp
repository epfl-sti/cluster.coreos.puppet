# Class: epflsti_coreos::gateway
#
# Configure this host as a gateway in an EPFL-STI CoreOS cluster
#
# This class is meant to be applied to machines that have their
# secondary network interface physically attached to the public
# Internet (the primary interface being reserved for the internal
# network, so that even gateways may be controlled with IPMI). There
# is no point in attaching this class to internal nodes, although it
# doesn't hurt (or in fact, do anything) if $external_address and
# $is_gateway are both left undefined (their default value).
#
# Each gateway host gets a dedicated public IP address. In addition,
# one of the gateways is the *active gateway* and is set up for
# outgoing traffic and NAT (see Actions: below).
# 
# === Parameters:
#
# [*external_address*]
#   IPv4 address on the external network
#
# [*external_interface*]
#   The name of the network interface connected to the Internet#
#
# [*external_netmask*]
#   IPv4 netmask on the external network
#
# [*external_gateway*]
#   IPv4 default route on the external network
#
# [*is_active*]
#   True on the active *outgoing* gateway (the one that holds the
#   $::gateway_vip); false on the hot standby(s). Note that this
#   is for egress traffic only; with care, ingress traffic can be
#   configured with an active-active setup (although this is not
#   implemented yet)
#
# === Global Variables:
#
# [*$::gateway_vip*]
#   The IP address that all internal nodes have set up as their default route
#   at provisioning time. The gateway that ${is_active} sets up this IP
#   as an alias for itself, and enables routing and masquerading.
#
# === Actions:
#
# If $external_address is set, this class overrides the network
# configuration set up by cloud-config.yml at provisioning time thusly:
#
# * Configure $external_interface with $external_address/$external_netmask
# * Change default route to point to $external_gateway

# In addition, if $is_active is set, this class aliases the ethbr4
# interface to $::gateway_vip and activates IPv4 masquerading through
# $external_interface.
class epflsti_coreos::gateway(
  $external_address = undef,
  $external_interface = $::epflsti_coreos::private::params::external_interface,
  $external_gateway = undef,
  $external_netmask = undef,
  $is_active = undef
) inherits epflsti_coreos::private::params {
  exec { "restart networkd in host":
    command => "/usr/bin/systemctl restart systemd-networkd.service",
    refreshonly => true
  }

  if ($external_address and $external_interface and $external_netmask and
      $external_gateway) {
        validate_string($external_address, $external_interface,
                        $external_netmask, $external_gateway)
    file { "/etc/systemd/network/50-${external_interface}-epflnet.network":
      ensure => "present",
      content => template("epflsti_coreos/networking/50-epflnet.network.erb")
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

  if ($is_active) {
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
