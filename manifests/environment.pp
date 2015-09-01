# Maintain /etc/environment from facts
#
# Class to load on all nodes
class epflsti_coreos::environment {
  file { "/opt/root/etc/environment":
      ensure => "present",
      content => template("epflsti_coreos/environment.erb")
  }

  # CHEAT: update /etc/systemd/system/puppet.service without re-installing
  file { "/etc/systemd/system/puppet.service":
    ensure => "present",
    content => template("epflsti_coreos/puppet.service.erb")
  } ~>
  exec { "restart Puppet from Puppet":
    command => "systemctl daemon-reload && systemctl restart puppet.service",
    path => $::path,
    refreshonly => true
  }
}
