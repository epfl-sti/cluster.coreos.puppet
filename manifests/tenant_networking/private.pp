class epflsti_coreos::tenant_networking::private {
  define tenant($ipv6_subnet, $ipv6_netmask = "80"){
    file { "/etc/systemd/network/ethbr-${name}.netdev":
      ensure => "present",
      content => inline_template("[NetDev]\nName=ethbr-${name}\nKind=bridge\n")
    }
  }
}
