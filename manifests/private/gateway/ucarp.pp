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
#
# [*failover_shared_secret*]
#   A password that serves for gateway nodes to authenticate each other
#   (used as the --pass flag to ucarp)
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

class epflsti_coreos::private::gateway::ucarp(
  $rootpath = $::epflsti_coreos::private::params::rootpath,
  $enable,
  $external_interface,
  $external_ipv4_address,
  $external_ipv4_gateway,
  $external_ipv4_vips,
  $failover_shared_secret
) inherits epflsti_coreos::private::params {
  file { "${rootpath}/etc/systemd/system/${::cluster_owner}.gateway-ucarp-external@.service":
    ensure => $enable ? { true => "file", default => "absent" },
    content => template('epflsti_coreos/external_vipv4@.service.erb')
  } ~>
  Exec["systemctl daemon-reload for ucarp configs"]

  $_common_dropin_dir = "${rootpath}/etc/systemd/system/${::cluster_owner}.gateway-ucarp-external@.service.d"
  file { $_common_dropin_dir:
    ensure => "directory"
  } ->
  file { "$_common_dropin_dir/secret.conf":
    content => inline_template("[Service]
Environment=\"UCARP_PASS=<%= @failover_shared_secret %>\"
"),
    mode => "0600",
    owner => "root",
    group => "root"
  } ~>
  Exec["systemctl daemon-reload for ucarp configs"]

  exec { "systemctl daemon-reload for ucarp configs":
    path => $::path,
    command => "systemctl daemon-reload",
    refreshonly => true
  }

  define ucarp_external_vipv4($all_vips) {
    $_vip = $title
    $_vhid = inline_template("<%= @all_vips.index(@_vip) + 100 %>")
    $_service = "${::cluster_owner}.gateway-ucarp-external@${_vip}.service"
    $_perinstance_dropin_dir = "${rootpath}/etc/systemd/system/${_service}.d"
    file { $_perinstance_dropin_dir:
      ensure => "directory"
    } ->
    file { "${_perinstance_dropin_dir}/ip-and-vhid.conf":
      content => inline_template("[Service]
Environment=UCARP_VIRTUALADDRESS=<%= @_vip %>
Environment=UCARP_VHID=<%= @_vhid %>
")
    } ~>
    Exec["systemctl daemon-reload for ucarp configs"] ->
    ::epflsti_coreos::private::systemd::unit { "${_service}":
      start => $::epflsti_coreos::private::gateway::ucarp::enable,
      enable => $::epflsti_coreos::private::gateway::ucarp::enable
    }
  }

  ucarp_external_vipv4 { $external_ipv4_vips:
    all_vips => $external_ipv4_vips
  }
}
