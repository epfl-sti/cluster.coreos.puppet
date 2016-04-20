# Configure networking pre-bootstrap.
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
# === Actions:
#
# * Set the FQDN in /etc/hostname, as is the CoreOS way
#
# * [TODO] Set up the bond0 interface and ethbr4 bridge as explained
#   above, using the Foreman-specified primary interface and IPv4
#   address, and the MAC address of the first (internal) physical
#   interface
#
# * Set up the default route and DNS server, in a way that lets
#   gateway.pp override the former seamlessly
#
# * Disable DHCPv4 on all interfaces
#
# === Parameters:
#
# [*rootpath*]
#    Where in the Puppet-agent Docker container, the host root is
#    mounted
#
# === Bootstrapping:
#
# This class is bootstrap-safe, as it only changes files and doesn't
# restart networkd. The obvious downside (or is it a feature?) is that
# "on-the-fly" network changes in production state (post-bootstrap)
# have no effect, until one restarts networkd by hand.

class epflsti_coreos::private::networking(
  $rootpath = $::epflsti_coreos::private::params::rootpath
) inherits epflsti_coreos::private::params {

  include ::epflsti_coreos::private::systemd

  file { "${rootpath}/etc/hostname":
    content => "${::fqdn}\n"
  }

  $internal_interfaces = delete(grep(split($::interfaces, ','), '^(en|eth)'), ["ethbr4", $::epflsti_coreos::gateway::external_interface])
  validate_bool(size($internal_interfaces) > 0)
  $first_internal_interface = $internal_interfaces[0]
  $first_mac_address = inline_template("<%= scope.lookupvar('macaddress_' + @first_internal_interface) %>")

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

  systemd::unit { "50-ethbr4-internal.network":
    content => template("epflsti_coreos/networking/50-ethbr4-internal.network.erb")
  }

  $::foreman_interfaces.each |$interface_obj| {
    $interface_name = $interface_obj["identifier"]
    if ($interface_name == $primary_interface) {
      systemd::unit { "00-${primary_interface}.network":
        content => "# Network configuration of ${primary_interface}
#
# Managed by Puppet, DO NOT EDIT
#
[Match]
Name=${primary_interface}

[Network]
DHCP=no
Bridge=ethbr4
"
      }
    } else {  # $interface_name != $primary_interface
      systemd::unit { "00-${interface_name}.network":
        ensure => "absent"
      }
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

  file { "${rootpath}/etc/resolv.conf":
    ensure => "file",
    content => inline_template('# Managed by Puppet, DO NOT EDIT

nameserver <%= @dns_vip %>
search <%= @domain %> <%= @domain.split(".").slice(-2, +100).join(".") %>
')
  }
}
