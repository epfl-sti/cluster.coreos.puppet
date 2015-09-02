# Maintain /etc/environment from facts
#
# Class to load on all nodes
class epflsti_coreos::environment {
  file { "/opt/root/etc/environment":
      ensure => "present",
      content => template("epflsti_coreos/environment.erb")
  }
}
