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
class epflsti_coreos::private::calico (
  $calicoctl_url = "http://www.projectcalico.org/builds/calicoctl",
  $rootpath = $epflsti_coreos::private::params::rootpath,
) inherits epflsti_coreos::private::params {
  include ::epflsti_coreos::private::systemd

  $calicoctl_bin = "${rootpath}/opt/bin/calicoctl"
  exec { "curl calicoctl":
    command => "curl -L -o ${calicoctl_bin} ${calicoctl_url} && chmod 0755 ${calicoctl_bin}",
    path => $::path,
    unless => "test -f ${calicoctl_bin}"
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
