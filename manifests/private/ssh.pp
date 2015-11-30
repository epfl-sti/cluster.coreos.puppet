# Class: epflsti_coreos::private::ssh
#
# Configure ssh access to bare metal.
#
# Use public keys (no passwords) just like
# https://coreos.com/os/docs/latest/cloud-config.html#ssh_authorized_keys,
# except you can add / remove administrators without reinstalling the
# entire fleet.
#
# === Global Variables:
#
# [*$::ssh_authorized_keys*]
#
#   The list of SSH authorized keys, as a comma-separated string. Uses
#   a global variable so that we can keep using the cloud-config mechanism
#   for access *during* bootstrap.
#
# === Actions:
#
# * Update /home/core/.ssh/authorized_keys
# * Set sane /etc/ssh/ssh_config
#
class epflsti_coreos::private::ssh {
  $rootpath = "/opt/root"
  file { "${rootpath}/home/core/.ssh/authorized_keys":
    ensure => "present",
    content => template("epflsti_coreos/ssh_authorized_keys.erb"),
    owner => 500,   # core - but from outside the Docker container
    group => 500    # core
  }
  file { "${rootpath}/etc/ssh/ssh_config":
    ensure => "file",
    content => template("epflsti_coreos/ssh_config.erb")
  }
}
