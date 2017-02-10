# Class: epflsti_coreos::private::docker
#
# Special docker tweaks for EPFL-STI clusters
#
# === Parameters:
#
# [*rootpath*]
#    Where in the Puppet-agent Docker container, the host root is
#    mounted
#
# [*docker_registry_address*]
#   The address of the internal Docker registry service, in host:port format
#
# === Actions:
#
# * Change command line of all dockerd's to enable IPv6,
#   etcd as the cluster store, and the internal registry without
#   a certificate
# * Restart the Docker daemon, except when bootstrapping
# * Download /opt/bin/pipework from GitHub

class epflsti_coreos::private::docker(
  $rootpath                = $::epflsti_coreos::private::params::rootpath,
  $docker_registry_address = $::epflsti_coreos::private::params::docker_registry_address
) inherits epflsti_coreos::private::params {
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
    enable => true
  } ->
  file { "/etc/systemd/system/docker.service.d":
    ensure => "directory"
  } ->
  file { "/etc/systemd/system/docker.service.d/50-puppet.conf":
    ensure => "present",
    content => "[Unit]
Wants=etcd2.service
After=etcd2.service

[Service]
Environment=\"DOCKER_OPTS=--insecure-registry registry.service.consul:5000 --registry-mirror=http://registry.service.consul:5000 --ipv6 --cluster-store=etcd://127.0.0.1:2379\"
",
    alias => "coreos-docker-private-registry-config"
  } ~>
  exec { "restart docker in host":
    command => "/usr/bin/systemctl daemon-reload && /usr/bin/systemctl restart docker.service",
    path => $::path,
    refreshonly => true,
  }

  if ($docker_registry_address) {
    concat::fragment { "Private Docker registry in /etc/environment":
      order => '40',
      target => "/etc/environment",
      content => "DOCKER_REGISTRY=${docker_registry_address}\n"
    }
  }

  exec { "Download /opt/bin/pipework":
    path => $::path,
    command => "ls -l ${rootpath}/opt/bin/pipework; set -e -x; exec > ${rootpath}/tmp/log 2>&1; curl -o ${rootpath}/opt/bin/pipework https://raw.githubusercontent.com/jpetazzo/pipework/master/pipework && chmod a+x ${rootpath}/opt/bin/pipework",
    creates => "${rootpath}/opt/bin/pipework"
  }

  # Poor man's "docker sync"
  # See https://coreos.com/os/docs/latest/scheduling-tasks-with-systemd-timers.html
  $docker_push_time_offset = seeded_rand(30, $::fqdn)
  systemd::unit { "docker-push.service":
    content => "[Unit]
Description=\"docker push\" all that we have (periodic task)

[Service]
Type=oneshot
ExecStart=/bin/sh -c \"docker images |grep ${docker_registry_address} |cut -f1 -d' ' | xargs -n 1 docker push\"
"
  } ->
  systemd::unit { "docker-push.timer":
    content => "[Unit]
Description=\"docker push\" all that we have every 30 mins

[Timer]
OnCalendar=*:${docker_push_time_offset}/30
",
    enable => true,
    start => true
  }
}
