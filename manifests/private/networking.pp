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
# Although there is no known reason why reconfiguring the network
# mid-flight on a production system would not work, this sounds enough
# of a bad idea that it has never been tested; init.pp only invokes
# this class when $lifecycle_state == "bootstrap".
class epflsti_coreos::private::networking(
  $primary_interface = $::epflsti_coreos::private::params::private_interface
)
inherits epflsti_coreos::private::params {
  include ::epflsti_coreos::private::systemd

  file { "${::epflsti_coreos::private::params::rootpath}/etc/hostname":
    content => "${::fqdn}\n"
  }

  systemd::unit { "ethbr4.netdev":
    content => join([
                     "[NetDev]\n",
                     "Name=ethbr4\n",
                     "Kind=bridge\n",
                     ])
  }

  systemd::unit { "50-ethbr4-internal.network":
    content => template("epflsti_coreos/networking/50-ethbr4-internal.network.erb")
  }

  systemd::unit { "00-${_primary_interface}.network":
    content => "# Network configuration of ${_primary_interface}
#
# Managed by Puppet, DO NOT EDIT
#
[Match]
Name=${_primary_interface}

[Network]
DHCP=no
Bridge=ethbr4
"
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
}
