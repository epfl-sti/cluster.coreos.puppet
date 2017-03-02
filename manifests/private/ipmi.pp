# Class: epflsti_coreos::private::ipmi
#
# Configure IPMI with a root password and so on.
class epflsti_coreos::private::ipmi() {
  $rootpath = "/opt/root"

  exec { "insert IPMI modules and wait for /dev/ipmi0 to appear":
    command => "/usr/sbin/chroot ${rootpath} /bin/bash -c 'modprobe ipmi_si; modprobe ipmi_devintf' || exit 1; set -e -x; for i in \$(seq 1 100); do test -c /dev/ipmi0 && exit 0; sleep 0.1; set +x; done; exit 2",
    path => $::path,
    creates => "/dev/ipmi0",
  } -> anchor { "dev_ipmi0_available": }

  exec { "define the default route":
    command => "ipmitool lan set 1 defgw ipaddr 0.0.0.0",
    unless => "ipmitool lan print 1 | grep \"Default Gateway IP\" | grep 0.0.0.0" ,
    path => $::path,
    require => Anchor["dev_ipmi0_available"]
  }

  # TODO: this is Nemesis-specific. Use proper net address variables
  $expected_ipmi_ipaddress = inline_template("<%= @ipaddress.sub('192.168.11', '192.168.10') %>")
  if ($expected_ipmi_ipaddress != $::ipmi_ipaddress) {
    exec { "correct IPMI address":
      command => "ipmitool lan set 1 ipaddr ${expected_ipmi_ipaddress}",
      path => $::path,
      require => Anchor["dev_ipmi0_available"]
    }
  }

  case $::boardproductname {
    "X7DBT": {
      $rootUserNo = 2
    }
    "X8DTT": {
      $rootUserNo = 3
    }
  }
  exec { "Create user root":
    command => "ipmitool user set name ${rootUserNo} root",
    path => $::path,
    unless => "ipmitool user list 1 |grep '^${rootUserNo}.*root'",
    require => Anchor["dev_ipmi0_available"]
  } ->
  exec { "Set up IPMI password":
    command => "ipmitool user set password ${rootUserNo} ${::ipmi_root_password}",
    path => $::path,
    unless => "ipmitool user test ${rootUserNo} 16 ${::ipmi_root_password}",
    require => Anchor["dev_ipmi0_available"]
  } ->
  exec { "Set up IPMI remote access":
    # Believe it or not, "ipmi=on" actually turns it off on both X7DBT and X8DDT! "ipmi=zoinx" works.
    command => "ipmitool lan set 1 auth ADMIN MD5 && ipmitool lan set 1 access on && ipmitool channel setaccess 1 ${rootUserNo} link=zoinx ipmi=zoinx callin=on privilege=4 && ipmitool user enable ${rootUserNo}",
    path => $::path,
    unless => "ipmitool channel getaccess 1 ${rootUserNo}|grep -q 'IPMI Messaging.*enabled'"
  }  -> anchor { "ipmi_configured": }

  if ($::lifecycle_stage == "production") {
    # Poor man's monitoring of the availability of the IPMI interface
    $_ipmi_ping_status = inline_template("<%= `ping -c 3 ${::ipmi_ipaddress} >/dev/null 2>&1; echo -n $?` %>")
    if ("0" != $_ipmi_ping_status) {
      exec { "Restart IPMI (${::ipmi_ipaddress} doesn't respond to pings from puppetmaster)":
        path => $::path,
        # Fail on purpose, so as to cause a red condition in Foreman
        command => "ipmitool bmc reset cold; /bin/false",
        require => Anchor["ipmi_configured"]
      }
    }
  }

  # When the System Event Log (SEL) is full, we get a boot-time message
  # to the tune of: SEL full, press F1 to continue :-(
  exec { "Empty IPMI bit bucket":
    path => $::path,
    command => "/bin/false",
    unless => "ipmitool sel clear",
    require => Anchor["dev_ipmi0_available"]
  }
}
