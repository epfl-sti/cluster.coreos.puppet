class epflsti_coreos::tenant_networking::private {
  define tenant(
    $br_name = "br-${name}",
    $ipv6_subnet,
    $ipv6_netmask = "80") {
    validate_string($br_name)
    validate_slength($br_name, 15)
    validate_string($ipv6_subnet)

    file { "/etc/systemd/network/ethbr-${br_name}.netdev":
      ensure => "present",
      content => inline_template("[NetDev]\nName=ethbr-${br_name}\nKind=bridge\n")
    } ~> Exec["restart networkd for tenant_networking"]
  }

  exec { "restart networkd for tenant_networking":
    command => "/usr/bin/systemctl restart systemd-networkd.service",
    refreshonly => true
  }

}
