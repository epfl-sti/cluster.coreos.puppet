class epflsti_coreos::tenant_networking() {
  define epflsti_coreos::tenant_networking::bridge(
    String $ipv6_subnet,
    String $ipv6_netmask = "80"
  ) {
    file { "/etc/systemd/network/ethbr-${name}.netdev":
      ensure => "present",
      content => inline_template("[NetDev]\nName=ethbr-${name}\nKind=bridge\n")
    }
  }

  epflsti_coreos::tenant_networking::bridge("core-consul")
}
