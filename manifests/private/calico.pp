# Configure Calico networking for Kubernetes
#
# === Parameters:
#
# [*calicoctl_url*]
#    Where to download the calicoctl binary from
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
  $cni_version = "v1.6.1"
) inherits epflsti_coreos::private::params {
  include ::epflsti_coreos::private::systemd

  $calicoctl_bin = "${rootpath}/opt/bin/calicoctl"
  $calicoctl_is_obsolete = (
    (versioncmp($::calicoctl_version, "0.99999999999") < 0))
  if $calicoctl_is_obsolete {
    exec { "Remove obsolete version of calicoctl":
      command => "rm -f $calicoctl_bin || true",
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

  # Inspired from the "install-cni" part of
  # https://coreos.com/kubernetes/docs/latest/deploy-master.html
  $_install_cni_docker_image = "quay.io/calico/cni:${cni_version}"
  exec { "install Calico CNI to /opt/cni/bin":
    path => "${::path}:${rootpath}/bin",
    unless => "test -f ${rootpath}/opt/cni/bin/calico",
    command => inline_template('true ; set -e -x
docker pull <%= @_install_cni_docker_image %>
docker run --rm --name calico-install-cni \
   --volume /opt/cni/bin:/host/opt/cni/bin \
   --volume /etc/cni/net.d:/host/etc/cni/net.d \
   -e SLEEP=false \
   <%= @_install_cni_docker_image %> /install-cni.sh')
  }
}
