# Comfort functions for systems administrators
#
# === Bootstrapping:
#
# This class is bootstrap-safe. In bootstrap mode, you get a
# .bash_history with commands useful for the bootstrap; likewise in
# production.
class epflsti_coreos::private::comfort(
  $rootpath = $::epflsti_coreos::private::params::rootpath)
inherits epflsti_coreos::private::params {

  file { "/home/core/.toolboxrc":
    owner => 500,
    group => 500,
    content => "TOOLBOX_DOCKER_IMAGE=registry.service.consul:5000/cluster.coreos.toolbox
TOOLBOX_DOCKER_TAG=latest
"
  }

  if ($::lifecycle_stage != "bootstrap") {
    exec { "ensure the toolbox is pulled":
      command => "/usr/bin/true",
      unless => "/usr/bin/env DOCKER_HOST=unix:///opt/root/var/run/docker.sock /opt/root/usr/bin/docker pull epflsti/cluster.coreos.toolbox || true"
    }
  }

  file { "/home/core/.bash_history":
    owner => 500,
    group => 500,
    replace => false,
    content => template("epflsti_coreos/bash_history.erb")
  }

  ensure_resource('file',
    ["${rootpath}/opt", "${rootpath}/opt/bin"],
    {'ensure' => 'directory' })
  file { "${rootpath}/opt/bin/fleetcheck":
    mode => '0755',
    content => template("epflsti_coreos/fleetcheck.erb"),
    require => File["${rootpath}/opt/bin"]
  }

  ########################### tmux ###################################
  $tmux_bin = "${rootpath}/opt/bin/tmux"
  $tmux_url = "https://github.com/epfl-sti/cluster.coreos.tmux/raw/master/tmux.gz"
  exec { "curl for /opt/bin/tmux":
    command => "curl -L -o ${tmux_bin} ${calicoctl_url}",
    path => $::path,
    creates => $tmux_bin
  }

  # Set up /dev/ptmx; only useful for ancient CoreOS (c35) afaict
  exec { "create /dev/ptmx":
    command => "set -e -x; rm ${rootpath}/dev/ptmx; mknod ${rootpath}/dev/ptmx c 5 2",
    path => $::path,
    unless => "test -c ${rootpath}/dev/ptmx"
  } ->
  file { "${rootpath}/dev/ptmx":
    owner => 'root',
    group => 'tty',
    mode => '0666'
  }

  systemd::unit { "tmux-permanent.service":
    content => "[Unit]
Description=Permanent tmux sessions for user core (survive container death upon ssh exit)
[Service]
ExecStart=/opt/bin/tmux -C
User=core
Group=core
RemainAfterExit=yes
",
    enable => true,
    start => true
  }
    
}
