# Class: epflsti_coreos::private::ipmi
#
# Configure IPMI with a root password and so on.
class epflsti_coreos::private::ipmi() {
  $rootpath = "/opt/root"

  exec { "insert IPMI modules and wait for /dev/ipmi0 to appear":
    command => "/usr/sbin/chroot ${rootpath }/bin/bash -e -x -c 'modprobe ipmi_si; modprobe ipmi_devintf; for i in \$(seq 1 100); do test -c /dev/ipmi0 && exit 0; sleep 0.1; set +x; done; exit 2'",
    path => $::path,
    creates => "${rootpath}/dev/ipmi0"
  } -> file { "/dev/ipmi0":
    ensure => "link",
    target => "${rootpath}/dev/ipmi0"
  }

  case $::boardproductname {
    "X7DBT": {
      exec { "Create user root":
        command => "ipmitool user set name 2 root",
        path => $path,
        unless => "ipmitool user list |grep '^2.*root'",
        require => File["/dev/ipmi0"]
      } ->
      exec { "Set up IPMI password":
        command => "ipmitool user set password 2 ${::ipmi_root_password}",
        path => $path,
        unless => "ipmitool user test 2 16 ${::ipmi_root_password}",
        require => File["/dev/ipmi0"]
      } ->
      # Believe it or not, "ipmi=on" actually turns it off! "ipmi=zoinx" works.
      exec { "Set up IPMI remote access":
        command => "ipmitool lan set 1 auth ADMIN MD5 && ipmitool lan set 1 access on && ipmitool channel setaccess 1 2 link=zoinx ipmi=zoinx callin=on privilege=4 && ipmitool user enable 2",
        path => $path,
        unless => "ipmitool channel getaccess 1 2|grep -q 'IPMI Messaging.*enabled'",
        require => File["/dev/ipmi0"]
      }
      # When the System Event Log (SEL) is full, we get a boot-time message
      # to the tune of: SEL full, press F1 to continue :-(
      exec { "Empty IPMI bit bucket":
        path => $path,
        command => "/bin/false",
        unless => "ipmitool sel clear",
        require => File["/dev/ipmi0"]
      }
    }
    # TODO: auto-configure our X8DTT's too (they have all been configured manually)
  }
}
