# Class: epflsti_coreos::private::docker
#
# Special docker tweaks for EPFL-STI clusters
#
# === Parameters:
#
# [*rootpath*]
#    Where in the Puppet-agent Docker container, the host root is
#    mounted
#
# === Actions:
#
# * Add select flags to the command line of all dockerd's
# * Restart the Docker daemon, except when bootstrapping
# * Download /opt/bin/pipework from GitHub
#
# === Bootstrapping:
#
# This class is bootstrap-aware.

class epflsti_coreos::private::docker(
  $rootpath                = $::epflsti_coreos::private::params::rootpath
) inherits epflsti_coreos::private::params {
  include ::epflsti_coreos::private::systemd

  systemd::unit { "docker-tcp.socket":
    content => "[Unit]
Description=Docker socket for the API

[Socket]
ListenStream=2375
BindIPv6Only=both
Service=docker.service

[Install]
WantedBy=sockets.target
",
    enable => true
  } ->
  file { "/etc/systemd/system/docker.service.d":
    ensure => "directory"
  } ->
  file { "/etc/systemd/system/docker.service.d/50-puppet.conf":
    ensure => "present",
    content => template("epflsti_coreos/docker.conf.erb"),
    alias => "coreos-docker-private-registry-config"
  }
  if ($::lifecycle_stage != "bootstrap") {
    exec { "restart docker in host":
      command => "/usr/bin/systemctl daemon-reload && /usr/bin/systemctl restart docker.service",
      path => $::path,
      refreshonly => true,
      subscribe => File["coreos-docker-private-registry-config"]
    }  
  }

  if ($::docker_registry) {
    concat::fragment { "Private Docker registry in /etc/environment":
      order => '40',
      target => "/etc/environment",
      content => "DOCKER_REGISTRY=${::docker_registry}\n"
    }
  }

  exec { "Download /opt/bin/pipework":
    path => $::path,
    command => "curl -o ${rootpath}/opt/bin/pipework https://raw.githubusercontent.com/jpetazzo/pipework/master/pipework && chmod a+x ${rootpath}/opt/bin/pipework",
    creates => "${rootpath}/opt/bin/pipework"
  }
}
