# Private class for ucarp high-availabilty VIP manager (only on gateway nodes)
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
#   Fixed IPv4 address on the external network, as a list of strings
#   in CIDR "IPv4/netmask" format. If undefined, do not configure a
#   gateway at all (keep the bonded pair set up by
#   epflsti_coreos::private::network); such a configuration is
#   intended for "cleaning up" a former gateway that has been physically
#   plugged back the "normal" way.
#
# [*external_ipv4_vips*]
#   The list of external-facing Virtual IPs (VIPs) that the cluster
#   manages at the gateway, in CIDR "IPv4/netmask" format.
#   Recommendation is to allocate one fixed IP out of the pool to each
#   physical node (and set $external_ipv4_address to that), and use
#   the remaining allocated IPs (supposedly all in the same subnet) as
#   the value of $external_ipv4_vips across all gateway nodes.
#
# [*failover_shared_secret*]
#   A password that serves for gateway nodes to authenticate each other
#   (used as the --pass flag to ucarp)
#
# [*gateway_ipv4_vips*]
#   The IPv4 addresses among which all internal (non-gateway) nodes pick up
#   exactly one to be their default route. The active gateway
#   nodes share these IPs as aliases for themselves, and enable routing
#   and masquerading.
#
# === Actions:
#
# * Run ucarp-in-Docker (https://hub.docker.com/r/nicolerenee/ucarp/)
#
# * As a follow-up to any given ucarp instance becoming the master,
#   alias the corresponding VIP to the corresponding interface. This
#   means that the VIP is the only dynamically managed resource; all
#   other network settings are supposed to be handled by
#   epflsti_coreos::private::network and/or epflsti_coreos::gateway
#  
# === Global Variables:
#
# [*$::ipv4_network*]
#   The CIDR network/netmask for the internal addresses of nodes
#   and masquerading.
#
# [*$::vipv4_affinity_table_yaml*]
#   A YAML map from VIPs (in dotted-quad notation) to the list of preferred
#   $::hostname's of gateways that should host them, ordered by preference.
#   (If a gateway is not listed, it gets priority 30)

class epflsti_coreos::private::gateway::ucarp(
  $rootpath = $::epflsti_coreos::private::params::rootpath,
  $enable,
  $external_interface,
  $external_ipv4_address,
  $external_ipv4_vips,
  $gateway_ipv4_vips = parseyaml($::gateway_ipv4_vips_yaml),
  $failover_shared_secret = $::ucarp_failover_shared_secret,
  $vipv4_affinity_table = parseyaml($::vipv4_affinity_table_yaml)
  ) inherits epflsti_coreos::private::params {
  define vipv4(
    $enable,
    $ip = $title,
    $where = "internal",
    $membership_protocol_ip,
    $interface
  ) {
    $vipv4_affinity_table = $::epflsti_coreos::private::gateway::ucarp::vipv4_affinity_table
    $failover_shared_secret = $::ucarp_failover_shared_secret
    ::epflsti_coreos::private::systemd::unit { "${::cluster_owner}.vip-${title}-${where}.service":
      start => $enable,
      enable => $enable,
      content => template('epflsti_coreos/vipv4.service.erb')
    }
  }

  vipv4 { $external_ipv4_vips:
    enable => $enable,
    where => "external",
    interface => $external_interface,
    membership_protocol_ip => inline_template("<%= @external_ipv4_address.split('/')[0] %>")
  }

  vipv4 { $gateway_ipv4_vips:
   enable => $enable,
    where => "internal",
    interface => "ethbr4",
    membership_protocol_ip => $::ipaddress
  }

  exec { "systemctl daemon-reload for ucarp configs":
    path => $::path,
    command => "systemctl daemon-reload",
    refreshonly => true
  }
    
}
