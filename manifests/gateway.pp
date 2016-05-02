# Class: epflsti_coreos::gateway
#
# Configure this host as a gateway in an EPFL-STI CoreOS cluster
#
# This class is meant to be applied to machines that have their
# secondary network interface physically attached to the public
# Internet (the primary interface being reserved for the internal
# network, so that even gateways may be controlled with IPMI). There
# is no point in attaching this class to an internal node, except for
# one round of Puppet to clean up a node that served as gateway
# previously.
#
# Each gateway host gets a set of public IP addresses (IPv4 and IPv6)
# and may advertise an internal IPv6 address range. In addition, one
# of the gateways is the *active gateway* and is set up for outgoing
# IPv4 traffic and NAT (see Actions: below).
# 
# Routing IPv6 (both natively and for VPN-as-a-service) is currently
# not supported.
#
# === Parameters:
#
# [*external_interface*]
#   The name of the network interface connected to the Internet
#   (required)  
#
# [*external_addresses*]
#   Addresses on the external network, as a list of strings in CIDR
#   "IPv4/netmask" format (IPv6 not supported yet). If empty, do not
#   configure a gateway at all (keep the bonded pair set up by
#   epflsti_coreos::private::network); this is useful to "clean up"
#   a former gateway that has been physically plugged back the
#   "normal" way
#
# [*external_gateway*]
#   IPv4 default route on the external network on the active
#   *outgoing* IPv4 gateway (the one that holds the
#   $::gateway_vip); undef on the hot standby(s). Note that this is
#   for egress traffic only; with care, ingress traffic can be
#   configured with an active-active setup (although this is not
#   implemented yet)
#
# [*ipv4_outgoing_active*]
#   True iff this is the *active* IPv4 gateway; that is, it has the
#   IPv4 VIP aliased on ethbr4.
#
# === Global Variables:
#
# [*$::gateway_vip*]
#   The IP address that all internal nodes have set up as their default route
#   at provisioning time. The gateway that ${ipv4_outgoing_active} sets up this IP
#   as an alias for itself, and enables routing and masquerading.
#
# [*$::cluster_owner*]
#   The prefix to set as the name to the haproxy Docker job
#
# [*$::public_web_domain*]
#   The domain in which all host names resolve to the public IP of
#   the cluster. Either set a wildcard CN in a domain you own, or
#   use 93.184.216.34.xip.io
#
# === Actions:
#
# If $external_addresses is set and not empty, this class overrides
# the network configuration set up by cloud-config.yml at provisioning
# time thusly:
#
# * Configure $external_interface with the $external_addresses
# * Activate IPv4 masquerading through $external_interface
# * Change the default route to point to $external_gateway
#
# Also, iff $ipv4_outgoing_active is not undef:
#
# * Alias the ethbr4 interface to $::gateway_vip
# * Set up IPv4 masquerading
# * Set up transparent proxying on port 80
#
class epflsti_coreos::gateway(
  $external_interface = undef,
  $external_addresses = [],
  $external_gateway = undef,
  $ipv4_outgoing_active = undef
) {
  validate_string($external_interface)

  include ::epflsti_coreos::private::systemd

  exec { "restart networkd in host":
    command => "/usr/bin/systemctl restart systemd-networkd.service",
    refreshonly => true
  }

  validate_array($external_addresses)
  if (size($external_addresses) > 0) {
    file { "/etc/systemd/network/50-${external_interface}-epflnet.network":
      ensure => "present",
      content => template("epflsti_coreos/networkd/50-epflnet.network.erb")
    } ~> Exec["restart networkd in host"]
  } else {
    exec { "Flush addresses on ${external_interface}":
      command => "/sbin/ip addr flush dev ${external_interface}",
      onlyif => "/sbin/ip addr show dev ${external_interface} | grep -q inet"
    }
  }

  private::systemd::unit { "${::cluster_owner}.haproxy.service":
    # Uses $::public_web_domain
    content => template('epflsti_coreos/haproxy.service.erb'),
    start => ($::lifecycle_stage == "production"),
    enable => size($external_addresses) > 0
  }
  private::systemd::unit { "${::cluster_owner}.squid-in-a-can.service":
    content => template('epflsti_coreos/squid-in-a-can.service.erb'),
    start => ($::lifecycle_stage == "production"),
    enable => size($external_addresses) > 0
  }

  if ($external_gateway and $ipv4_outgoing_active) {
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
    exec { "Enable transparent forwarding":
      path => $path,
      command => "/sbin/iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to 3129 -w",
      unless => "/sbin/iptables -t nat -L -v |grep 3129",
    }
    exec { "Disable default route through ethbr4":
      command => "/sbin/ip route del default dev ethbr4",
      onlyif => "/sbin/ip route show dev ethbr4 | grep -q ^default"
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
    exec { "Disable transparent forwarding":
      path => $path,
      command => "/sbin/iptables -t nat -D PREROUTING -p tcp --dport 80 -j REDIRECT --to 3129 -w",
      onlyif => "/sbin/iptables -t nat -L -v |grep 3129",
    }
    exec { "Disable default route through ${external_interface}":
      command => "/sbin/ip route del default dev ${external_interface}",
      onlyif => "/sbin/ip route show dev ${external_interface} | grep -q ^default"
    }
  }
}
