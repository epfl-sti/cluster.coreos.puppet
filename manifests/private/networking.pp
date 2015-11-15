# Configure networking pre-bootstrap.
#
# The main IPv4 address of each CoreOS node is bridged. This lets
# Docker containers (most notably, the Foreman / Puppet master)
# claim an IP address on the internal (RFC1918) IPv4 network.
# If the container moves, that IP (called a "Virtual IP", or VIP)
# can stay the same, and the clients will catch up (after their
# ARP timeout expires) with zero reconfiguration.
#
# docker0 is *not* used, because claiming an IP in this
# way is obviously reserved to trusted containers.
#
class epflsti_coreos::private::networking {
  include ::epflsti_coreos::private::systemd

  $_primary_interface = inline_template(
    '<%= @foreman_interfaces.first{|i| i.primary}["identifier"] %>')

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

  fail("A

B")

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
