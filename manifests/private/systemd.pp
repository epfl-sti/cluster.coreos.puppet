# Library for dealing with systemd in EPFL-STI clusters

define unit (
  $enable = true,
  $start = true,
  $content = undef
) {

  file { "/etc/systemd/system/${name}":
    content => $content,
  }

  if ($enable) {
    exec { "Enabling ${name} in systemd":
      command => "/usr/bin/systemctl enable ${name}",
      path => $::path,
      unless => "/usr/bin/systemctl is-enabled ${name}",
      require => File["/etc/systemd/system/${name}"]
    }  
  }

  if ($start and $::lifecycle_stage == "production") {
    exec { "Restarting ${name} in systemd":
      command => "/usr/bin/systemctl daemon-reload && /usr/bin/systemctl reload-or-restart ${name}",
      path => $::path,
      require => File["/etc/systemd/system/${name}"]
    }
  }
}
