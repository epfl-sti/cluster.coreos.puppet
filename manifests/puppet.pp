# Class: epflsti_coreos::puppet
#
# Install or update Puppet-in-Docker.
#
# Note that we are talking about the steady-state Puppet here; not the
# bootstrap run before reboot. See ../README.md for details.
class epfsti_coreos::puppet() {
  $rootpath = "/opt/root"

  $facts = {
    lifecycle_stage => "production",
    ipaddress => $::ipaddress,
    provision_git_id => $::provision_git_id,
    install_sh_version => $::install_sh_version
  }

  file { "${rootpath}/etc/systemd/system/puppet.service":
    content => template('epflsti_coreos/puppet.service.erb'),
  }
}
