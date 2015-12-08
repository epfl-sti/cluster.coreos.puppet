# Class: epflsti_coreos::private::puppet
#
# Install or update Puppet-in-Docker.
#
# === Actions:
#
# * Create / maintain /etc/puppet/puppet.conf
#
# * Ensure that the Puppet service exists
#
# * Restart Puppet-in-Docker if needed (not at bootstrap time)
# 
# === Bootstrapping:
#
# At bootstrap time, prepare for steady-state only; *don't* reload
# Puppet even if /etc/puppet/puppet.conf changed.

class epflsti_coreos::private::puppet() {
  include ::epflsti_coreos::private::systemd

  file { "/etc/puppet/puppet.conf":
    ensure => "present",
    content => template('epflsti_coreos/puppet.conf.erb')
  }

  file { "/etc/puppet/auth.conf":
    ensure => "present",
    content => template('epflsti_coreos/puppet-auth.conf.erb')
  }

  if ($::lifecycle_stage == "production") {
    exec { "Restart Puppet":
      command => "systemctl restart puppet.service",
      path => $::path,
      refreshonly => true,
      subscribe => [File["/etc/puppet/puppet.conf"],
                    File["/etc/puppet/auth.conf"]]
    }
  }

  # Used in template('epflsti_coreos/puppet.service.erb'):
  $puppet_docker_tag = "epflsti/cluster.coreos.puppet:latest"
  $facts = {
    lifecycle_stage => "production",
    ipaddress => $::ipaddress,
    hostname => $::hostname,
    fqdn => $::fqdn,
    provision_git_id => $::provision_git_id,
    install_sh_version => $::install_sh_version
  }

  systemd::unit { "puppet.service":
    content => template('epflsti_coreos/puppet.service.erb')
  }
}
