# Configure things that change depending on the host.
#
# This class is intended to be loaded on all nodes
class epflsti_coreos::hostvars {
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
