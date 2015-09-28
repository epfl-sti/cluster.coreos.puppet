class epflsti_coreos::tenant_networking::private {
  define tenant($ipv6_subnet, $ipv6_netmask = "80"){
    file { "/etc/systemd/network/ethbr-${name}.netdev":
      ensure => "present",
      content => inline_template("[NetDev]\nName=ethbr-${name}\nKind=bridge\n")
    } ~> Exec["restart networkd for tenant_networking"]
  }

  exec { "restart networkd for tenant_networking":
    command => "/usr/bin/systemctl restart systemd-networkd.service",
    refreshonly => true
  }

}
