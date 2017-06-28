# DNS client and server setup
#
# We configure all nodes' resolv.conf to use a quorum of dead-simple
# DNS servers (we use unbound: https://www.unbound.net/)
#
# === Parameters:
#
# [*cluster_owner*]
#   The prefix for all tasks run by the cluster owner
#
# [*dns_servers*]
#   A hash associating host names to IP addresses where the
#   redundant DNS servers of the cluster should run.
#
class epflsti_coreos::private::networking::dns(
  $dns_servers = parseyaml($::quorum_members_yaml),
  $cluster_owner = $::cluster_owner
  ) {

  $_is_dns_server = !(! $dns_servers[$::fqdn])

  file { "${rootpath}/etc/resolv.conf":
    ensure => "file",
    content => inline_template('# Managed by Puppet, DO NOT EDIT

nameserver <%= @dns_vip %><%# TODO: put $dns_servers here once they work %>
search <%= @domain %> <%= @domain.split(".").slice(-2, +100).join(".") %>
')
  }

  if ($_is_dns_server) {
    ::epflsti_coreos::private::docker::image { "cluster.unbound":
      Dockerfile => "FROM alpine:latest
RUN apk update; apk add unbound
"
    } ->
    ::epflsti_coreos::private::systemd::unit { "${cluster_owner}.unbound-dns.service":
    }
  }
}
  
