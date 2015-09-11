# Configure things that change depending on the host.
#
# This class is intended to be loaded on all nodes.
#
# === Parameters:
#
# [*ups_hosts*]
#   A list of short hostnames that have uninterruptible power plugged into them.
#
# [*etcd_region*]
#   The "region=" metadata for fleet
#
# === Actions:
#
# * Create /etc/facter/facts.d/epflsti.txt to override ipaddress
#   (working around
#   https://ask.puppetlabs.com/question/5112/how-to-force-facter-not-to-use-private-ip-address/) and provide a custom fact "has_ups"
# 

class epflsti_coreos::hostvars(
  $ups_hosts = [],
  $etcd_region = undef
) {
  $has_ups = member($ups_hosts, $::hostname)

  # Custom facts
  file { "/etc/facter":
    ensure => "directory",
    tag => "bootstrap"
  } ->
  file { "/etc/facter/facts.d":
    ensure => "directory",
    tag => "bootstrap"
  } ->
  file { "/etc/facter/facts.d/epflsti.txt":
    ensure => "present",
    content => template("epflsti_coreos/facts-epflsti.txt.erb"),
    tag => "bootstrap"
  }

  # Maintain /etc/environment for unit files to source host-specific data from
  file { "/opt/root/etc/environment":
      ensure => "present",
      content => template("epflsti_coreos/environment.erb"),
      tag => "bootstrap"
  }

    file { "/etc/systemd/system/fleet.service.d":
      ensure => "directory"
    } ->
    file { "/etc/systemd/system/fleet.service.d/50-metadata.conf":
      ensure => "present",
      content => template("epflsti_coreos/50-fleet-metadata.conf.erb")
    } ~>
    exec { "restart fleet in host":
      command => "/usr/bin/systemctl daemon-reload && /usr/bin/systemctl restart fleet.service",
      refreshonly => true
    }
}
