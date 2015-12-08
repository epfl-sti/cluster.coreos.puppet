# Class: epflsti_coreos::private::puppet
#
# Install or update Puppet-in-Docker.
#
# === Parameters:
#
# [*rootpath*]
#    Where in the Puppet-agent Docker container, the host root is
#    mounted
#
# [*docker_registry_address*]
#   The address of the internal Docker registry service, in host:port format
#
# [*docker_puppet_image_name*]
#   The (unqualified) image name for Puppet-agent-in-Docker
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
#
# In production, do a "docker pull" the version of $
# as downloaded from the internal Docker registry (whose host name is
# computed as docker-registry.<domain>).

class epflsti_coreos::private::puppet(
  $rootpath                = $::epflsti_coreos::private::params::rootpath,
  $docker_registry_address  = $::epflsti_coreos::private::params::docker_registry_address,
  $docker_puppet_image_name = $::epflsti_coreos::private::params::docker_puppet_image_name
  ) inherits epflsti_coreos::private::params {
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

  ###############################################################
  # Puppet agent's Docker container
  ###############################################################

  # Poor man's crontab
  file { ["/etc/facter", "/etc/facter/facts.d"]:
    ensure => "directory"
  } ->
  exec { "pull latest ${docker_puppet_image_name} from ${docker_registry_address}":
    path => $::path,
    command => "true",
    unless => "${rootpath}/usr/bin/docker pull ${docker_registry_address}/${docker_puppet_image_name}:latest; imagever=$(${rootpath}/usr/bin/docker images -q ${docker_registry_address}/${docker_puppet_image_name}); if [ -n \$imagever ]; then echo cluster_coreos_puppet_latest=\$imagever > /etc/facter/facts.d/cluster_coreos_puppet_latest.txt; fi; exit 0",
  }

  # Compute the variables used in template('epflsti_coreos/puppet.service.erb'):
  $_puppet_docker_version = ($::cluster_coreos_puppet_latest or $::cluster_coreos_puppet_current)

  if ($_puppet_docker_version) {
    $puppet_docker_tag = "${docker_registry_address}/${docker_puppet_image_name}:${$_puppet_docker_version}"
    $extra_facts = {
      cluster_coreos_puppet_current => $_puppet_docker_version
    }
  } else {
    # Internal registry unreachable or not installed - Use version from the Internets, so as
    # not to fail the provisioning cycle if bootstrapping.
    $puppet_docker_tag = "epflsti/cluster.coreos.puppet:latest"
    $extra_facts = {}
  }
  $facts = merge({
    lifecycle_stage => "production",
    ipaddress => $::ipaddress,
    hostname => $::hostname,
    fqdn => $::fqdn,
    provision_git_id => $::provision_git_id,
    install_sh_version => $::install_sh_version
  }, $extra_facts)

  systemd::unit { "puppet.service":
    content => template('epflsti_coreos/puppet.service.erb')
  }
}
