# Class to load on all nodes
class epflsti_coreos {
  file { "/etc/environment":
      ensure => "present",
      content => template("epflsti_coreos/environment.erb")
  }
}
