# Class: epflsti_coreos::private::consul
#
# Configure a consul quorum and proxies cluster-wide.
#
# === Actions:
#
# * Run the official consul Docker image on all nodes; quorum members
#   are masters.
#
# === Parameters:
#
# [*enabled*]
#   Whether this node hosts a Consul quorum member or agent
#
# [*datacenter*]
#   The datacenter name (passed as --datacenter to consul)
#
# [*consul_version*]
#    The version of the consul agent to run
#  
# [*consulcli_url*]
#    Where to download the consul-cli command from
#  
# [*quorum_members*]
#   A YAML-encoded dict associating quorum member names with their
#   IP address.
#
# [*recursors*]
#    List of DNS servers to forward queries to (if outside of .consul domain)
#
# [*rootpath*]
#    Where in the Puppet-agent Docker container, the host root is
#    mounted
#
class epflsti_coreos::private::consul(
  $enabled = true,
  $datacenter = $::datacenter_short_name,
  $consul_version = "0.9.0",
  $consulcli_url = "https://github.com/CiscoCloud/consul-cli/releases/download/v0.3.1/consul-cli_0.3.1_linux_amd64.tar.gz",
  $quorum_members = parseyaml($::quorum_members_yaml),
  $recursors = parseyaml($::dns_servers_yaml),
  $rootpath = $epflsti_coreos::private::params::rootpath
) inherits epflsti_coreos::private::params {
  $_is_member = !empty(intersection([$::ipaddress], values($quorum_members)))
  $_consul_service = inline_template("#
# Managed by Puppet, DO NOT EDIT
#

[Unit]
Description=Run consul on each node

[Service]
ExecStartPre=/usr/bin/docker pull consul:<%= @consul_version %>
ExecStart=/usr/bin/docker run --rm --name=%p.service --net=host \
    -e CONSUL_ALLOW_PRIVILEGED_PORTS=true \
    consul:<%= @consul_version %> agent \
    -datacenter=<%= @datacenter %> \
    -client :: \
    -bind=<%= @ipaddress %> -dns-port 53 \
    <%if @_is_member %> -ui -server -bootstrap-expect=2 <% end %> \
    <% @quorum_members.each do |hostname, ip| -%>
    -join <%= ip %> \
    <% end -%>
    <% @recursors.each do |recursor| -%>
    -recursor <%= recursor %> \
    <% end %>
ExecStop=-/usr/bin/docker rm -f %p.service
")
  systemd::unit { "stiitops.consul.service":
    content => $_consul_service,
    enable => $enabled,
    start => $enabled
  }

  $_registrator_service =  inline_template("#
# Managed by Puppet, DO NOT EDIT
#

[Unit]
Description=Registers all Docker jobs into Consul
Requires=docker.service stiitops.consul.service
After=docker.service stiitops.consul.service

[Service]
Restart=always
RestartSec=5s
TimeoutStartSec=120
TimeoutStopSec=25
EnvironmentFile=/etc/environment
<%# Ad-hoc health checks for registry services on ports 5000 and 5001: %>
Environment=SERVICE_5000_CHECK_HTTP=/
Environment=SERVICE_5000_CHECK_INTERVAL=20s
Environment=SERVICE_5000_CHECK_TIMEOUT=60s
Environment=SERVICE_5001_CHECK_HTTP=/
Environment=SERVICE_5001_CHECK_INTERVAL=20s
Environment=SERVICE_5001_CHECK_TIMEOUT=60s
ExecStart=/usr/bin/docker run --rm --name=%p --net=host \
   --volume=/var/run/docker.sock:/tmp/docker.sock       \
  gliderlabs/registrator:latest      \
  consul://<%= @ipaddress %>:8500
ExecStop=-/usr/bin/docker rm -f %p
  ")

  systemd::unit { "stiitops.consul.registrator.service":
    content => $_registrator_service,
    enable => $enabled,
    start => $enabled
  }


  exec { 'download consul-cli.tgz':
    creates => "/tmp/consul-cli.tgz",
    path => $::path,
    command => "curl -L -o /tmp/consul-cli.tgz ${consulcli_url}"
  } ->
  exec {'unpack consul-cli from consul-cli.tgz':
    creates => "${rootpath}/opt/bin/consul-cli",
    path => $::path,
    command => "true ; set -e -x; cd /tmp; tar zxvf consul-cli.tgz ; cp consul-cli*/consul-cli ${rootpath}/opt/bin/consul-cli"
  }
}
