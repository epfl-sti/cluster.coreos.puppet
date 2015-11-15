# Class: epflsti_coreos::private::docker
#
# Special docker tweaks for EPFL-STI clusters
#
# === Actions:
#
# * Adds --insecure-registry docker-registry.ne.cloud.epfl.ch:5000
#   on the command line of all dockerd's
#

class epflsti_coreos::private::docker() {
  file { "/etc/systemd/system/docker.service.d":
    ensure => "directory"
  } ->
  file { "/etc/systemd/system/docker.service.d/50-insecure-private-registry.conf":
    ensure => "present",
    content => template("epflsti_coreos/50-insecure-private-registry.conf.erb"),
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
