# Class: epflsti_coreos::private::quorum_proxy
#
# Configure haproxy to forward TCP connections to crucial distributed
# services (such as Kube-apiserver) to the hosts where such services
# actually run.
#
# Note: it would be possible, but unwise to use this to proxy etcd.
# Besides preventing setups where Docker depends on etcd (such as
# calico as a Docker-network backend), this saves us nothing disk-wise
# as etcd is already bundled with CoreOS.
#

class epflsti_coreos::private::quorum_proxy(
  $rootpath = $epflsti_coreos::private::params::rootpath,
) inherits epflsti_coreos::private::params {
  include epflsti_coreos::private::systemd

  concat { "${rootpath}/etc/haproxy.cfg":
    ensure => "present"
  } ~>
  systemd::unit { "quorum-haproxy.service":
    start => true,
    enable => true,
    content => inline_template("
[Unit]
Description=TCP proxy to quorum members
After=docker.service
Requires=docker.service

[Service]
ExecStartPre=-/usr/bin/docker rm -f %n
ExecStartPre=-/usr/bin/docker pull haproxy:alpine
SuccessExitStatus=98
ExecStart=/bin/bash -c 'set -e -x; grep frontend /etc/haproxy.cfg || sleep infinity; exec docker run --rm --name %n <% -%>
  --net=host <% -%>
  -v /etc/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg <% -%>
  -v /etc/kubernetes/ssl/<%= @fqdn %>-worker-key-and-cert.pem:/etc/client-cert-and-key.pem <% -%>
  -v /etc/kubernetes/ssl/ca.pem:/etc/ca.pem <% -%>
  haproxy:alpine'

[Install]
WantedBy=multi-user.target
")
  }

  define quorum_forward(
    $mode = "tcp",
    $port,
    $target_port = $port,
    $rootpath = $::epflsti_coreos::private::quorum_proxy::rootpath,
    $quorum_members = parseyaml($::quorum_members_yaml)
  ) {
    $is_member = !empty(intersection([$::ipaddress], values($quorum_members)))

  if (! $is_member) {
      $timeouts = "
      timeout connect 5000ms
      timeout client 50000ms
      timeout server 50000ms
"
      $quorum_list = inline_template("<% @quorum_members.each do |fqdn, ip|
      @host = fqdn.split('.')[0] -%>
      server <%= @host %> <%= ip %>:<%= @target_port %> check port <%= @target_port %> inter 60000 <%= @mode == 'http_to_https' ? 'ssl crt /etc/client-cert-and-key.pem ca-file /etc/ca.pem' : '' %>
<% end %>")

      concat::fragment { "${title} fragment of ${rootpath}/etc/haproxy.cfg":
        target => "${rootpath}/etc/haproxy.cfg",
        content => inline_template("
frontend <%= @title %>
<%= @timeouts %>
      mode <%= @mode == 'tcp' ? 'tcp' : 'http' %>
      bind *:<%= @port %>
      default_backend <%= @title %>-quorum

backend <%= @title %>-quorum
      mode <%= @mode == 'tcp' ? 'tcp' : 'http' %>
<%= @timeouts %>
<%= @quorum_list %>
")
      }
    }
  }
}
