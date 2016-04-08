# Configure networking pre-bootstrap.
#
# The primary physical interface of each CoreOS node is bridged on a
# bridge device called ethbr4 ("Ethernet bridge for IPv4"). This is so
# that Docker containers (most notably, the Foreman / Puppet master)
# may claim an IP address on the internal (RFC1918) IPv4 network. If
# the container moves, that IP (called a "Virtual IP", or VIP) can
# stay the same, and the clients will catch up (after their ARP
# timeout expires) with zero reconfiguration.
#
# Note that gateway nodes receive an additional layer of network
# configuration; see ../gateway.pp. The interaction between the
# two is managed using networkd's cascading preferences mechanism.
#
# === Actions:
#
# * Set the FQDN in /etc/hostname, as is the CoreOS way
#
# * Set up the ethbr4 bridge as explained above, using the
#   Foreman-specified primary interface and IPv4 address
#
# * Set up the default route and DNS server, in a way that lets
#   gateway.pp override the former seamlessly
#
# * Disable DHCPv4 on all physical interfaces, primary or not, so as
#   to save valuable DHCP address space
#
# === Parameters:
#
# [*primary_interface*]
#   The name of the network interface connected to the internal network
#
# === Bootstrapping:
#
# This class is bootstrap-safe, as it only changes files and doesn't
# restart networkd.

class epflsti_coreos::private::networking(
  $primary_interface = $::epflsti_coreos::private::params::primary_interface
)
inherits epflsti_coreos::private::params {
  include ::epflsti_coreos::private::systemd

  file { "${::epflsti_coreos::private::params::rootpath}/etc/hostname":
    content => "${::fqdn}\n"
  }

  systemd::unit { "ethbr4.netdev":
    content => "[NetDev]
Name=ethbr4
Kind=bridge
"
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
