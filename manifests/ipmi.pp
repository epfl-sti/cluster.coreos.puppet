# Class: epflsti_coreos::ipmi
#
# Configure IPMI with a root password and so on.
class epflsti_coreos::ipmi() {
  $activate = $::boardproductname ? {
    "XX7DBT" => "zoinx",  # Believe it or not, "on" actually turns things off!
    default  => "on"
  }
  exec { "Set up IPMI remote access":
    command => "ipmitool lan set 1 auth ADMIN MD5 && ipmitool lan set 1 access on && ipmitool user set name 2 root && ipmitool user set password 2 ${::ipmi_root_password} && ipmitool channel setaccess 1 2 link=$activate ipmi=$activate callin=on privilege=4 && ipmitool user enable 2",
    path => $path,
    unless => "ipmitool channel getaccess 1 2|grep -q 'IPMI Messaging.*enabled'"
  }
}
