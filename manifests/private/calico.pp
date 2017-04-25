# Configure Calico networking for Kubernetes
#
# === Parameters:
#
# [*calicoctl_version*]
#    The version number to use for the calicoctl command (hint: look
#    it up on http://docs.projectcalico.org/v2.1/releases/)
#
# [*cni_version*]
#    The version number to use for the /opt/cni/bin adapter commands
#    (hint: look up versions on http://docs.projectcalico.org/v2.1/releases/)
#
# [*rootpath*]
#    Where in the Puppet-agent Docker container, the host root is
#    mounted
#
# === Actions:
#
# * Install the calicoctl command to /opt/bin
#
# * Run Calico on the local node (calico-node.service), which provides
#   Calico API and routing services as well as "docker network"
#   (libnetwork) services (as sockets under /run/docker/plugins)
#
# * Install the CNI binaries to /opt/cni/bin, so that Kubernetes may
#   also create / delete IPv6 endpoints with Calico
#
# === Pre-requisites:
#
# $::ipaddress6 must be set up on the correct interface
# (see networking.pp)
#
class epflsti_coreos::private::calico (
  $calicoctl_version = "1.1.3",
  $cni_version = "1.6.2",
  $rootpath = $epflsti_coreos::private::params::rootpath
) inherits epflsti_coreos::private::params {
  include ::epflsti_coreos::private::systemd

  $calicoctl_url = "https://github.com/projectcalico/calicoctl/releases/download/v${calicoctl_version}/calicoctl"
  $calicoctl_bin = "${rootpath}/opt/bin/calicoctl"
  $_calicoctl_is_obsolete = (
    (versioncmp($::calicoctl_version,
                $epflsti_coreos::private::calico::calicoctl_version) < 0))
  $_calico_cni_is_obsolete = (
    (versioncmp($::calico_cni_version,
                $epflsti_coreos::private::calico::cni_version) < 0))
  if $_calicoctl_is_obsolete {
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
    # Inspired from https://github.com/projectcalico/calico-containers/blob/master/docs/CalicoAsService.md
    start => true,
    enable => true,
    content => inline_template("[Unit]
Description=Calico node service
After=docker.service etcd2.service
Requires=docker.service etcd2.service

[Service]
ExecStartPre=-/usr/bin/docker rm -f calico-node
ExecStart=/opt/bin/calicoctl node run --init-system --name=<%= @hostname %> --ip6=<%= @ipaddress6 %>
ExecStop=-/usr/bin/docker stop calico-node

[Install]
WantedBy=multi-user.target
"),
    subscribe => Exec["curl calicoctl"]
  }

  # Obsolete; calicoctl v1.1.1's "calicoctl node run" now provides
  # and exposes /run/docker/plugins directly
  systemd::unit { "calico-libnetwork.service":
    ensure => "absent",
    start => false
  }

  # Inspired from the "install-cni" part of
  # https://coreos.com/kubernetes/docs/latest/deploy-master.html
  $_install_cni_docker_image = "quay.io/calico/cni:v${cni_version}"
  exec { "Install Calico CNI to /opt/cni/bin":
    path => "${::path}:${rootpath}/bin",
    creates => "${rootpath}/opt/cni/bin/calico",
    command => inline_template('true ; set -e -x
docker pull <%= @_install_cni_docker_image %>
docker run --rm --name calico-install-cni \
   --volume /opt/cni/bin:/host/opt/cni/bin \
   -e SLEEP=false \
   <%= @_install_cni_docker_image %> /install-cni.sh')
  }

  if $_calico_cni_is_obsolete {
    exec { "Remove obsolete version of /opt/cni/bin":
      command => "rm -f \"${rootpath}\"/opt/cni/bin/*",
      path => $::path
    } -> Exec["Install Calico CNI to /opt/cni/bin"]
  }
}
