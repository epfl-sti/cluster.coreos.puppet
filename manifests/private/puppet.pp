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
# [*docker_registry_prefix*]
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
  $docker_registry_prefix  = "epflsti",
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

  $puppet_docker_tag = "${docker_registry_prefix}/${docker_puppet_image_name}:latest"

  # Poor man's crontab
  exec { "pull ${puppet_docker_tag}":
    path => $::path,
    command => "false",
    unless => template('epflsti_coreos/docker_pull_puppet.sh'),
  }

  # Compute the variables used in template('epflsti_coreos/puppet.service.erb'):
  if ($::cluster_coreos_puppet_latest) {
    $_puppet_docker_version = $::cluster_coreos_puppet_latest
  } else {
    $_puppet_docker_version = $::cluster_coreos_puppet_current
  }

  if ($_puppet_docker_version) {
    $extra_facts = {
      cluster_coreos_puppet_current => $_puppet_docker_version
    }
  } else {
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

  systemd::docker_service { "puppet":
    description => "Puppet agent in Docker",
    net => "host",
    privileged => true,
    image => $puppet_docker_tag,
    args => "agent --no-daemonize --logdest=console --environment=production",
    volumes => [  
                  "/:/opt/root",
                  "/dev:/dev",
                  "/etc/systemd:/etc/systemd",
                  "/etc/ssh:/etc/ssh",
                  "/etc/puppet:/etc/puppet",
                  "/var/lib/puppet:/var/lib/puppet",
                  "/var/run:/var/run",
                  "/home/core:/home/core",
                  "/etc/os-release:/etc/os-release:ro",
                  "/etc/lsb-release:/etc/lsb-release:ro",
                  "/etc/coreos:/etc/coreos:rw",
                  "/run:/run:ro",
                  "/usr/bin/systemctl:/usr/bin/systemctl:ro",
                  "/usr/bin/fleetctl:/usr/bin/fleetctl:ro",
                  "/lib64:/lib64:ro",
                  "/lib/modules:/lib/modules:ro",
                  "/usr/lib64/systemd:/usr/lib64/systemd",
                  "/usr/lib/systemd:/usr/lib/systemd",
                  "/sys/fs/cgroup:/sys/fs/cgroup:ro",
                  ],
    env => parsejson(inline_template(
      '<%= @facts.map { |fact, value| "FACTER_#{fact}=#{value}" }.to_json %>')),
    start => $::lifecycle_stage ? {
      "production" => true,
      default => undef
    }
  } -> anchor { "puppet.service configured": }

  $should_restart_puppet = (
    ($::cluster_coreos_puppet_latest and ($::cluster_coreos_puppet_latest !=
                                          $::cluster_coreos_puppet_current))
    or (! $::lifecycle_stage)) # Happened on a third of the cluster on 2016-01-22 for some reason
  if ($should_restart_puppet) {
    exec { "Restarting Puppet":
      command => "systemctl restart puppet.service",
      path => $::path,
      require => Anchor["puppet.service configured"]
    }
  }
}
