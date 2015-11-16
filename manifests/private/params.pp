# Computed default values for classes of the epflsti_coreos module
#
# Variables:
#
# [*primary_interface*]
#   The name of the network interface connected to the internal network
#
# [*external_interface*]
#   The name of the network interface connected to the Internet, for
#   gateway nodes (those that have the epflsti_coreos::gateway class
#   installed); unused for internal nodes

class epflsti_coreos::private::params {
  $primary_interface = inline_template(
    '<%= @foreman_interfaces.first{|i| i.primary}["identifier"] %>')

  case $::interfaces {
      /enp1s0f1/: { $external_interface = "enp1s0f1" }
      /enp4s0f1/: { $external_interface = "enp4s0f1" }
      default: { $external_interface = undef }
  }
}
