# Library for dealing with systemd in EPFL-STI clusters

class epflsti_coreos::private::systemd {
  define unit (
    $ensure = "present",
    $enable = undef,
    $start = undef,
    $content = undef
  ) {
  
    if ($name =~ /\.(service)$/) {
      $_kind = "service"
      $_subdir = "system"
    } elsif ($name =~ /\.(network|netdev)$/) {
      $_kind = "network"
      $_subdir = "network"
    } elsif ($name =~ /\.(socket)$/) {
      $_kind = "socket"
      $_subdir = "system"
    } else {
      fail("Cannot determine unit type for ${name}")
    }

    if ($ensure == "absent") {
      file { "/etc/systemd/${_subdir}/${name}":
        ensure => "absent",
      }
    } else {
      if ($content == undef) {
        $_file_prereqs = []
      } else {
        file { "/etc/systemd/${_subdir}/${name}":
          content => $content,
        }
        $_file_prereqs = File["/etc/systemd/${_subdir}/${name}"]
      }
  
      if ($enable == undef) {
        $_do_enable = $_kind == "service"
      } else {
        $_do_enable = $enable
      }
  
      if ($_do_enable) {
        exec { "Enabling ${name} in systemd":
          command => "/usr/bin/systemctl enable ${name}",
          path => $::path,
          unless => "/usr/bin/systemctl is-enabled ${name}",
          require => $_file_prereqs
        }  
      }
  
      if ($::lifecycle_stage == "bootstrap") {
        $_do_start = false
      } elsif ($start == undef) {
        $_do_start = $_kind == "service"
      } else {
        $_do_start = $start
      }
    
      if ($_do_start) {
        exec { "Restarting ${name} in systemd":
          command => "/usr/bin/systemctl daemon-reload && /usr/bin/systemctl reload-or-restart ${name}",
          path => $::path,
          subscribe => $_file_prereqs,
          refreshonly => true
        }
      }
    }  # if ($ensure != "absent")
  }  # define unit
}
