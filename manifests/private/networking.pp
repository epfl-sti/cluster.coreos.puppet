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

  systemd::unit { "00-${_primary_interface}.network":
    content => join([
              "[Match]\n",
              "Name=${_primary_interface}\n",
              "\n",
              "[Network]\n",
              "DHCP=no\n",
              "Bridge=ethbr4\n"
                     ])
  }

  systemd::unit { "70-leave-unconfigured.network":
    content => join([
              "[Match]\n",
              "Name=enp*\n",
              "\n",
              "[Network]\n",
              "DHCP=no\n"
                     ])
  }

}
