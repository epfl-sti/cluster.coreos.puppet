# Configure things that change depending on the host.
#
# This class is intended to be loaded on all nodes
# === Parameters:
#
# [*ups_hosts*]
#   A list of short hostnames that have uninterruptible power plugged into them.
#
# === Actions:
#
# * Create /etc/facter/facts.d/epflsti.txt to override ipaddress
#   (working around
#   https://ask.puppetlabs.com/question/5112/how-to-force-facter-not-to-use-private-ip-address/) and provide a custom fact "has_ups"
# 

class epflsti_coreos::hostvars(
  $ups_hosts = [],
) {
  $has_ups = member($::hostname, $ups_hosts)

  # Custom facts
  file { "/etc/facter":
    ensure => "directory"
  } ->
  file { "/etc/facter/facts.d":
    ensure => "directory"
  } ->
  file { "/etc/facter/facts.d/epflsti.txt":
    ensure => "present",
    content => template("epflsti_coreos/facts-epflsti.txt.erb")
  }

  # Maintain /etc/environment from facts
  file { "/opt/root/etc/environment":
      ensure => "present",
      content => template("epflsti_coreos/environment.erb")
  }
}
