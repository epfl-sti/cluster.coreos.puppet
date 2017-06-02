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
    content => "TOOLBOX_DOCKER_IMAGE=${::toolbox_docker_image}
TOOLBOX_DOCKER_TAG=${::toolbox_docker_tag}
TOOLBOX_BIND=\"--bind=/:/media/root --bind=/usr:/media/root/usr --bind=/run:/media/root/run --bind=/home/core:/home/core\"
"
  }

  if ($::lifecycle_stage != "bootstrap") {
    exec { "ensure the toolbox is pulled":
      command => "/usr/bin/true",
      unless => "/usr/bin/env DOCKER_HOST=unix:///opt/root/var/run/docker.sock /opt/root/usr/bin/docker pull epflsti/cluster.coreos.toolbox || true"
    }

    class { "::epflsti_coreos::private::comfort::tmux":
    }
  }

  file { "/home/core/.bash_history":
    owner => 500,
    group => 500,
    replace => false,
    content => template("epflsti_coreos/bash_history.erb")
  }

  file { "/home/core/.bashrc":
    owner => 500,
    group => 500,
    replace => true,
    content => template("epflsti_coreos/bashrc.erb")
  }
  
  ensure_resource('file',
    ["${rootpath}/opt", "${rootpath}/opt/bin"],
    {'ensure' => 'directory' })
  file { "${rootpath}/opt/bin/fleetcheck":
    mode => '0755',
    content => template("epflsti_coreos/fleetcheck.erb"),
    require => File["${rootpath}/opt/bin"]
  }    
}
