# Class: epflsti_coreos::private::docker
#
# Special docker tweaks for EPFL-STI clusters
#
# === Actions:
#
# * Add select flags to the command line of all dockerd's
# * Restart the Docker daemon, except when bootstrapping
#
# === Bootstrapping:
#
# This class is bootstrap-aware.

class epflsti_coreos::private::docker() {
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
    enable => true,
    start => true
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
}
