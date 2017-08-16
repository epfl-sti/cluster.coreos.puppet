# Configure networking pre-bootstrap (IPv4 and IPv6).
#
# The physical interfaces of each CoreOS node are partitioned into
# *internal* (tied to the internal network - The vast majority of
# them) and *external* (tied to the EPFL or other public IPv4
# network). Nodes that have at least one external interface are called
# "gateway" nodes; they receive an additional layer of network
# configuration (see ../gateway.pp) which takes precedence over the
# configuration in this class thanks to networkd's cascading
# preferences mechanism.
#
# Internal interfaces (assuming there are more than one) are bonded
# together in a zero-SPOF active/passive ("mode=1") configuration, and
# then bridged into a device called ethbr4 ("Ethernet bridge for
# IPv4"). This is so that Docker containers (most notably, the Foreman
# / Puppet master) may claim an IP address on the internal (RFC1918)
# IPv4 network. If the container moves, that IP (called a "Virtual
# IP", or VIP) can stay the same, and the clients will catch up (after
# their ARP timeout expires) with zero reconfiguration.
#
# IPv6 configuration is also handled here. We can't SLAAC, because in
# Calico-land all hosts are routers and routers don't listen to router
# advertisement packets. Also, it's just smarter to use
# easy-to-memorize IPv6 addresses.
#
# === Parameters:
#
# [*rootpath*]
#    Where in the Puppet-agent Docker container, the host root is
#    mounted
#
# [*$ipv6_physical_address*]
#   The IPv6 address to use.
#
# [*$ipv6_physical_netmask*]
#   The IPv6 netmask to use.
#
# [*gateway_ipv4_vips*]
#   The list of the IPv4 addresses among which to choose from (in a
#   pseudorandom fashion to achieve load balancing)
#
# === Actions:
#
# * Set the FQDN in /etc/hostname, as is the CoreOS way
#
# * If there is more than one physical internal interface, set up the
#   bond0 interface for active-passive layer 2 failover with MII
#   monitoring. A node thus appears to always keep the same MAC
#   address (the one of its first internal interface), regardless of
#   failover state. (Actual load balancing with 802.3ad LACP would
#   require "intelligent" (expensive) switches.)
#
# * Set up the ethbr4 bridge as explained above, using the
#   Foreman-specified primary interface and IPv4 address, and the MAC
#   address of the first (internal) physical interface. Enlist
#   either bond0 or the sole internal interface into it.
#
# * Set up the IPv6 address as per the parameters (no IPv6 routing)
#
# * Set up the default route and DNS server, in a way that lets
#   gateway.pp override the former seamlessly
#
# * Disable DHCPv4 on all interfaces
#
# === Bootstrapping:
#
# This class is bootstrap-safe, as it only changes files and doesn't
# restart networkd. The obvious downside (or is it a feature?) is that
# "on-the-fly" network changes in production state (post-bootstrap)
# have no effect, until one restarts networkd by hand.

class epflsti_coreos::private::networking(
  $rootpath = $::epflsti_coreos::private::params::rootpath,
  $ipv6_physical_address = $epflsti_coreos::private::params::ipv6_physical_address,
  $ipv6_physical_netmask = $epflsti_coreos::private::params::ipv6_physical_netmask,
  $gateway_ipv4_vips = parseyaml($::gateway_ipv4_vips_yaml)
) inherits epflsti_coreos::private::params {

  include ::epflsti_coreos::private::systemd

  file { "${rootpath}/etc/hostname":
    content => "${::fqdn}\n"
  }
  class {"::epflsti_coreos::private::networking::dns": }

  $internal_interfaces = delete(grep(split($::interfaces, ','), '^(en|eth)'), ["ethbr4", $::epflsti_coreos::gateway::external_interface])
  validate_bool(size($internal_interfaces) > 0)
  $has_bond = size($internal_interfaces) > 1
  $first_internal_interface = $internal_interfaces[0]
  $first_mac_address = inline_template("<%= scope.lookupvar('permanent_macaddress_' + @first_internal_interface) %>")

  systemd::unit { "ethbr4.netdev":
    content => inline_template("#
# Managed by Puppet, DO NOT EDIT
#
[NetDev]
Name=ethbr4
Kind=bridge
MACAddress=<%= @first_mac_address %>
")
  }

  if (! $::epflsti_coreos::gateway::enabled) {
    $internal_default_route = fqdn_rotate($gateway_ipv4_vips)[0]
  } else {
    $internal_default_route = undef
  }
  systemd::unit { "50-ethbr4-internal.network":
    content => template("epflsti_coreos/networkd/50-ethbr4-internal.network.erb")
  }

  # https://github.com/coreos/bugs/issues/298#issuecomment-143335399
  ensure_resource("file", "${rootpath}/etc/modprobe.d",
                  {ensure => "directory" })
  file { "${rootpath}/etc/modprobe.d/bonding.conf":
    ensure => "file",
    content => "#
# Managed by Puppet, DO NOT EDIT
#
options bonding max_bonds=0
"
  }


  split($::interfaces, ',').each |$interface_name| {
    if (empty(intersection([$interface_name], $internal_interfaces))) {
      systemd::unit { "00-${interface_name}.network":
        ensure => "absent"  # Leave it for ../gateway.pp to manage (under a
                            # different file name)
      }
    } else {
      systemd::unit { "00-${interface_name}.network":
        content => inline_template("# Network configuration of <%= @interface_name %>
#
# Managed by Puppet, DO NOT EDIT
#
[Match]
Name=<%= @interface_name %>

[Network]
DHCP=no
<%if @has_bond -%>
Bond=bond0
<% else -%>
Bridge=ethbr4
<% end -%>
")
      }
    }  # if this is an internal interface
  }  # loop over each interface

  if ($has_bond) {
    systemd::unit { "bond0.netdev":
      content => inline_template("# Definition of device bond0
#
# Managed by Puppet, DO NOT EDIT
#
[NetDev]
Name=bond0
Kind=bond

[Bond]
Mode=active-backup
")

    }
    systemd::unit { "bond0.network":
      content => inline_template("# Network configuration of device bond0
#
# Managed by Puppet, DO NOT EDIT
#
[Match]
Name=bond0

[Link]
MACAddress=<%= @first_mac_address %>

[Network]
DHCP=no
Bridge=ethbr4
")
    }
  } else {  # No bonding device
    systemd::unit { ["bond0.netdev", "bond0.network"]:
      ensure => "absent"
    }
  }

  systemd::unit { "99-fallback-physical.network":
    content => "# Fallback configuration for physical interfaces.
#
# Unless specified otherwise, physical interfaces
# are left unconfigured, and do not attempt to DHCP.
#
# Managed by Puppet, DO NOT EDIT
#
[Match]
Name=enp*

[Network]
DHCP=no
"

  }

  if ($internal_default_route) {
    class { "epflsti_coreos::private::networking::default_route":
      default_route => $internal_default_route
    }
  }
}
