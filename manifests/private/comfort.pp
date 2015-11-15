# Comfort functions for systems administrators
#
class epflsti_coreos::private::comfort() {
  file { "/home/core/.toolboxrc":
    owner => "core",
    content => @("TOOLBOXRC")
      TOOLBOX_DOCKER_IMAGE=epflsti/cluster.coreos.toolbox
      TOOLBOX_DOCKER_TAG=latest
      | TOOLBOXRC
  }

  file { "/opt/bin/fleetcheck":
    permissions => '0755',
    content => template("epflsti_coreos/fleetcheck.erb)
  }
}
