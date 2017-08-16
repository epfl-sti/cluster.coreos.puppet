# DNS and /etc/hosts setup
#
# Each node is assumed to be running a DNS server on port 53 (e.g. Consul)
#
# In order for workloads (Docker) to be able to reach it, we want
# to use the host's IP address, not 127.0.0.1 in resolv.conf
#
# === Parameters:
#
# [*rootpath*]
#    Where in the Puppet-agent Docker container, the host root is
#    mounted
#
class epflsti_coreos::private::networking::dns(
  $rootpath = $::epflsti_coreos::private::params::rootpath
) inherits epflsti_coreos::private::params {
  # Note: the file class with content cannot be used here, as it tries
  # to perform an atomic update with rename(2). This is unfortunately
  # not possible with the host's /etc/resolv.conf, which bind-mounted
  # into every Docker container. (For now, this is not a problem for
  # /etc/hosts.)
  file_line { "nameserver in ${rootpath}/etc/resolv.conf":
    path => "${rootpath}/etc/resolv.conf",
    line => inline_template("nameserver <%= @ipaddress %>"),
    match => "^nameserver"
  }

  $_all_hosts = query_facts('Class[epflsti_coreos]', ['ipaddress'])
  file { "${rootpath}/etc/hosts":
    content => inline_template('# Managed by Puppet, DO NOT EDIT

127.0.0.1	localhost
::1		localhost

<% @_all_hosts.sort.map do |hostname, facts| -%>
<%= facts["ipaddress"] %> <%= hostname %> <%= hostname.split(".")[0] %>
<% end %>
')
  }
}
