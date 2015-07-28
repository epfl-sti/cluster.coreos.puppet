# Class: epflsti_coreos::ipmi
#
# Configure IPMI with a root password and so on.
class epflsti_coreos::ipmi() {
  exec { "Set IPMI root password":
    command => "ipmitool user set name 2 root && ipmitool user set password 2 ${::ipmi_root_password} && ipmitool channel setaccess 1 2 link=on ipmi=on callin=on privilege=4 && ipmitool user enable 2",
    path => $path,
    unless => "ipmitool user list|grep -q 'root.*true.*true.*true'"
  }
}
