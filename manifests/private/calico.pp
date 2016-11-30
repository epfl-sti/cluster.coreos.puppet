# Configure Calico as per https://github.com/projectcalico/calico-containers/blob/master/docs/calico-with-docker/docker-network-plugin/ManualSetup.md
#
# === Parameters:
#
# [*calicoctl_url*]
#    Where to download the calicoctl script from
#
# [*rootpath*]
#    Where in the Puppet-agent Docker container, the host root is
#    mounted
#
# === Actions:
#
# * Run Calico on the local node
#
# === Pre-requisites:
#
# $::ipaddress6 must be set up on the correct interface
# (see networking.pp)
#
class epflsti_coreos::private::calico (
  $calicoctl_url = "http://www.projectcalico.org/builds/calicoctl",
  $rootpath = $epflsti_coreos::private::params::rootpath,
) inherits epflsti_coreos::private::params {
  include ::epflsti_coreos::private::systemd

  $calicoctl_bin = "${rootpath}/opt/bin/calicoctl"
  if versioncmp($::calicoctl_version, "0.99999999999") < 0 {
    exec { "Remove obsolete version of calicoctl":
      command => "rm $calicoctl_bin",
      path => $::path
    } -> Exec["curl calicoctl"]
  }
  
  exec { "curl calicoctl":
    command => "curl -L -o ${calicoctl_bin} ${calicoctl_url}",
    path => $::path,
    creates => "${calicoctl_bin}"
  } ->
  file { "${calicoctl_bin}":
    ensure => "file",
    mode => "0755"
  } ->
  systemd::unit { "calico-node.service":
    start => true,
    enable => true,
    content => template('epflsti_coreos/calico-node.service.erb'),
  }

  systemd::unit { "calico-libnetwork.service":
    start => true,
    enable => true,
    content => template('epflsti_coreos/calico-libnetwork.service.erb'),
  }
}
