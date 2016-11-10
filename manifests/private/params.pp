# Computed default values for classes of the epflsti_coreos module
#
# Variables:
#
# [*rootpath*]
#    Where in the Puppet-agent Docker container, the host root is
#    mounted
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

  $has_ups = member(parseyaml($::ups_hosts), $::hostname)

  $docker_registry_address = "registry.service.consul:5000"
  $docker_puppet_image_name = "cluster.coreos.puppet"

  $etcd2_quorum_members = $::quorum_members
  $_quorum_members = parseyaml($::quorum_members)
  $kubernetes_masters = parseyaml(inline_template('<%= @_quorum_members.keys().to_yaml %>'))

  $ipv6_physical_network = $::ipv6_physical_network   # From Foreman
  $ipv6_physical_netmask = inline_template('<%= @ipv6_physical_network.split("/")[1] %>')
  # Deduct IPv6 address from the last digits in the IPv4 address. Yes,
  # "real" hexadecimal is expected in IPv6 CIDR; but we keep the faux
  # decimal because it makes typing IPv6 addresses easier.
  $ipv6_physical_address = inline_template('<%= @ipv6_physical_network.split("/")[0] + @ipaddress.split(".")[-1] %>')
}
