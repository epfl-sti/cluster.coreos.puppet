# Computed default values for classes of the epflsti_coreos module
#
# Variables:
#
# [*rootpath*]
#    Where in the Puppet-agent Docker container, the host root is
#    mounted
#
# [*primary_interface*]
#   The name of the network interface connected to the internal network
#
# [*external_interface*]
#   The name of the network interface connected to the Internet, for
#   gateway nodes (those that have the epflsti_coreos::gateway class
#   installed); unused for internal nodes
#
# [*docker_registry_address*]
#   The address of the internal Docker registry service, in host:port format
#
# [*docker_puppet_image_name*]
#   The (unqualified) image name for Puppet-agent-in-Docker
#
# [*etcd2_quorum_members*]
#   A YAML-encoded dict associating etcd2 quorum member names with their
#   peer-advertised URLs.

class epflsti_coreos::private::params {
  $rootpath = "/opt/root"

  $primary_interface = inline_template(
    '<%= @foreman_interfaces.find{|i| i["primary"]}["identifier"] %>')

  case $::interfaces {
      /enp1s0f1/: { $external_interface = "enp1s0f1" }
      /enp4s0f1/: { $external_interface = "enp4s0f1" }
      default: { $external_interface = undef }
  }

  $has_ups = member(parseyaml($::ups_hosts), $::hostname)

  $docker_registry_address = "registry.service.consul:5000"
  $docker_puppet_image_name = "cluster.coreos.puppet"

  $etcd2_quorum_members = $::quorum_members
}
