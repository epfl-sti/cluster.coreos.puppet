# Library for dealing with systemd in EPFL-STI clusters

class epflsti_coreos::private::systemd {
  define unit (
    $enable = undef,
    $start = undef,
    $content = undef
  ) {
  
    file { "/etc/systemd/system/${name}":
      content => $content,
    }

    $_is_service = !(!($name =~ m/\.service$/));
  
    if ($enable == undef) {
      $_do_enable = $_is_service;
    } else {
      $_do_enable = $enable;
    }

    if ($_do_enable) {
      exec { "Enabling ${name} in systemd":
        command => "/usr/bin/systemctl enable ${name}",
        path => $::path,
        unless => "/usr/bin/systemctl is-enabled ${name}",
        require => File["/etc/systemd/system/${name}"]
      }  
    }

    if ($::lifecycle_stage == "bootstrap") {
      $_do_start = false;
    } elsif ($start == undef) {
      $_do_start = $_is_service;
    } else {
      $_do_start = $start;
    }
  
    if ($_do_start) {
      exec { "Restarting ${name} in systemd":
        command => "/usr/bin/systemctl daemon-reload && /usr/bin/systemctl reload-or-restart ${name}",
        path => $::path,
        require => File["/etc/systemd/system/${name}"]
      }
    }
  }
}
