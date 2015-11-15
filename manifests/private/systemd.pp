# Library for dealing with systemd in EPFL-STI clusters

class epflsti_coreos::private::systemd {
  define unit (
    $enable = undef,
    $start = undef,
    $content = undef
  ) {
  
    if ($name =~ /\.(service)$/) {
      $_kind = "service"
    } elsif ($name =~ /\.(network|netdev)$) {
      $_kind = "network"
    } else {
      fail("Cannot determine unit type for ${name}")
    }
  
    if ($content == undef) {
      $_file_prereqs = []
    } else {
      file { "/etc/systemd/${_kind}/${name}":
        content => $content,
      }
      $_file_prereqs = File["/etc/systemd/${_kind}/${name}"]
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
        require => $_file_prereqs
      }
    }
  }
}
