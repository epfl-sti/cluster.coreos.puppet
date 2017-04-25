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
# [*rootpath*]
#    Where in the Puppet-agent Docker container, the host root is
#    mounted
#
# [*external_interface*]
#   The name of the network interface connected to the Internet
#   (required)  
#
# [*external_ipv4_address*]
#   Fixed IPv4 address on the external network, as a string
#   in CIDR "IPv4/netmask" format. If undefined, do not configure a
#   gateway at all (keep the bonded pair set up by
#   epflsti_coreos::private::network); such a configuration is
#   intended for "cleaning up" a former gateway that has been physically
#   plugged back the "normal" way.
#
# [*external_ipv4_gateway*]
#   IPv4 default route on the external network for the gateway nodes
#   (mandatory)
#
# [*external_ipv4_vips*]
#   The list of external-facing Virtual IPs (VIPs) that the cluster
#   manages at the gateway, in CIDR "IPv4/netmask" format.
#   Recommendation is to allocate one fixed IP out of the pool to each
#   physical node (and set $external_ipv4_address to that), and use
#   the remaining allocated IPs (supposedly all in the same subnet) as
#   the value of $external_ipv4_vips across all gateway nodes.

# [*enable_boundary_caching*]
#   If true, set up a transparent cache for egress HTTP traffic on port 80
#
# === Global Variables:
#
# [*$::ipv4_network*]
#   The CIDR network/netmask for the internal addresses of nodes
#   and masquerading.
#
# [*$::gateway_ipv4_vip*]
#   The IPv4 address that all internal (non-gateway) nodes have set up
#   as their default route at provisioning time. The active gateway
#   node sets up this IP as an alias for itself, and enables routing
#   and masquerading.
#
# [*$::cluster_owner*]
#   The prefix to set as the name to the haproxy Docker job
#
# [*$::public_web_domain*]
#   A domain in which all host names resolve to the public IP of
#   the cluster. Either set a wildcard CN in a domain you own, or
#   use 93.184.216.34.xip.io
#
# === Actions:
#
# This class overrides the network configuration set up by
# cloud-config.yml at provisioning time thusly:
#
# * Configure $external_interface with the $external_ipv4_address
#
# * Change the default route to point to $external_ipv4_gateway
#
# * Set up as many ucarp instances as needed to handle
#   internal and external VIPs
# 
# === Bootstrapping:
#
# This class does *NOT* try to turn an installing node into a gateway.
# Most actions that take effect at run time, are thus guarded by
# a test on ($::lifecycle_stage == "production")

class epflsti_coreos::gateway(
  $rootpath = $::epflsti_coreos::private::params::rootpath,
  $external_interface,
  $external_ipv4_address,
  $external_ipv4_gateway,
  $external_ipv4_vips = parseyaml($::external_ipv4_vips_yaml),
  $enable_boundary_caching = true
) inherits epflsti_coreos::private::params {
  if ($external_ipv4_address) {
    validate_string($external_ipv4_address)
  }
  validate_string($external_interface)
  validate_string($external_ipv4_gateway)
  validate_array($external_ipv4_vips)

  include ::epflsti_coreos::private::systemd

  # Feature selection
  $_transparent_forwarding_port = 3129
  if ($external_ipv4_address) {
    $enabled = true   # For networking.pp
    $_enable_haproxy = true
    $_enable_masquerade = true
    $_enable_transparent_forwarding = true
    $_enable_squid_and_transparent_proxying = $enable_boundary_caching
    class { "epflsti_coreos::private::networking::default_route":
      default_route => $external_ipv4_gateway
    }
  } else {
    # Clean-up case (host is being discharged from acting as gateway)
    $enabled = false
    $_enable_haproxy = false
    $_enable_masquerade = false
    $_enable_transparent_forwarding = false
    $_enable_squid_and_transparent_proxying = false
    # Default route expectation managed by private/networking.pp instead
  }

  # Set up external IPv4 addresses
  # Template uses $external_interface, $external_ipv4_address and
  # $external_ipv4_gateway
  if ($external_ipv4_address) {
    file { "/etc/systemd/network/50-${external_interface}-epflnet.network":
      ensure => "present",
      content => template("epflsti_coreos/networkd/50-epflnet.network.erb")
    } ~> Exec["restart networkd in host"]
  } else {
    file { "/etc/systemd/network/50-${external_interface}-epflnet.network":
      ensure => "absent"
    } ~> Exec["restart networkd in host"]
    exec { "Flush addresses on ${external_interface}":
      command => "/sbin/ip addr flush dev ${external_interface}",
      onlyif => "/sbin/ip addr show dev ${external_interface} | grep -q inet"
    } ~> Exec["restart networkd in host"]
  }

  private::systemd::unit { "stiitops.cache.gateway.service":
    content => inline_template("#
# Managed by Puppet, DO NOT EDIT

  [Unit]
Description=The \"head\" Squid on a gateway node
Requires=docker.service
After=docker.service
;; TODO: this should also mesh with the iptables-redirect.service somehow

[Service]
Restart=on-failure
RestartSec=60s
ExecStartPre=-/usr/bin/docker pull epflsti/cluster-proxy-squid-egress-gateway
ExecStart=/usr/bin/docker run --rm --name=%p --net=host \
              -e PUBLIC_WEB_DOMAIN=<%= @public_web_domain %> \
              -e IPADDRESS=<%= @ipaddress %> \
              -e SQUID_PORT=<%= @_transparent_forwarding_port %> \
              epflsti/cluster-proxy-squid-egress-gateway
ExecStop=-/usr/bin/docker rm -f %p
    "),
    enable => $enabled,
    start => $enabled and ($::lifecycle_stage == "production")
  }

  ######## Bootstrap-time actions stop here #########

  if ($::lifecycle_stage == "production") {
    exec { inline_template("<%= @_enable_masquerade ? 'Enable': 'Disable' %> masquerading for egress traffic on <%= @external_interface %>"):
      path => $::path,
      command => inline_template("/sbin/iptables -t nat <%= @_enable_masquerade ? '-A' : '-D' %> POSTROUTING -o <%= @external_interface %> -j MASQUERADE"),
      unless => inline_template("/bin/true ; <%= @_enable_masquerade ? '' : '!' %> iptables -t nat -L -v| grep -q 'MASQUERADE.*<%= @external_interface %>'")
    }

    class { "epflsti_coreos::private::gateway::ucarp":
      enable => !(! $external_ipv4_address),
      external_interface => $external_interface,
      external_ipv4_address => $external_ipv4_address,
      external_ipv4_vips => $external_ipv4_vips
    }

    # haproxy for ingress traffic
    private::systemd::docker_service { "${::cluster_owner}.haproxy":
      description => "Serves all Consul servers to the open Web with NO ACCESS CONTROL WHATSOEVER",
      net => "host",
      image => "ciscocloud/haproxy-consul",
      env => [ "HAPROXY_DOMAIN=${::public_web_domain}" ],
      start => $_enable_haproxy,
      enable => $_enable_haproxy
    }

    # Set up / tear down Squid and transparent proxying
    # I am told I should use a systemd.service instead of a quirky "exec".
    $_iptables_spec = "-p tcp -d '!'${::ipv4_network} --dport 80 -j REDIRECT --to <%= @_transparent_forwarding_port %> -w"
    exec { inline_template("<%= @_enable_transparent_forwarding ? 'Enable': 'Disable' %> transparent forwarding"):
      path => $path,
      command => inline_template("/sbin/iptables -t nat \
  <%= @_enable_transparent_forwarding ?  '-I' : '-D' %> PREROUTING \
  -p tcp --dport 80 -j DNAT \
  --to <%= @ipaddress %>:<%= @_transparent_forwarding_port %> -w"),
      unless => inline_template("/bin/true ; <%= @_enable_transparent_forwarding ? '' : '!' %> iptables -t nat -L -v| grep -q <%= @_transparent_forwarding_port %>")
    }
  }  # end if ($::lifecycle_stage == "production")
}
