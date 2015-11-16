# Comfort functions for systems administrators
#
class epflsti_coreos::private::comfort() {
  file { "/home/core/.toolboxrc":
    owner => 500,
    group => 500,
    content => "TOOLBOX_DOCKER_IMAGE=epflsti/cluster.coreos.toolbox
TOOLBOX_DOCKER_TAG=latest
"
  }

  file { "/home/core/.bash_history":
    owner => 500,
    group => 500,
    replace => false,
    content => "fleetctl list-units
fleetctl list-machines
etcdctl member list
etcdctl cluster-health
journalctl -xe
journalctl -l
systemctl list-unit-files
systemctl cat puppet.service
docker exec puppet.service puppet agent -t
"
  }

  $rootpath = "/opt/root"
  file { "/opt/bin/fleetcheck":
    mode => '0755',
    content => template("epflsti_coreos/fleetcheck.erb")
  }
}
