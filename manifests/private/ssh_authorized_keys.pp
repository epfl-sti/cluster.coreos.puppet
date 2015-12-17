# Class: epflsti_coreos::private::ssh_authorized_keys
#
# Early configuration of /home/core/.ssh/authorized_keys
#
# === Variables:
#
# [*rootpath*]
#    Where in the Puppet-agent Docker container, the host root is
#    mounted
#
# === Global Variables:
#
# [*$::ssh_authorized_keys*]
#
#   The list of SSH authorized keys, as a comma-separated string, for
#   access as user core. Uses a global variable so that we can keep
#   using the cloud-config mechanism for access *during* bootstrap.
#
# === Bootstrapping:
#
# This class is intended to run at bootstrap time, so that
# administrators can gain access even in the case of a failed
# bootstrap.
class epflsti_coreos::private::ssh_authorized_keys(
  $rootpath = $epflsti_coreos::private::params::rootpath
) inherits epflsti_coreos::private::params {
  file { "${rootpath}/home/core/.ssh/authorized_keys":
    ensure => "present",
    content => template("epflsti_coreos/ssh_authorized_keys.erb"),
    owner => 500,   # core - but from outside the Docker container
    group => 500    # core
  }
}
