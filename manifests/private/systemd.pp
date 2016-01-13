# Library for dealing with systemd in EPFL-STI clusters

class epflsti_coreos::private::systemd {
  # Function: systemd::unit
  #
  # Declare a systemd unit.
  #
  # The kind of service is auto-detected from the name's suffix (e.g.
  # .service, .netdev etc)
  #
  # Parameters:
  #
  # [*ensure*]
  #    If set to "absent", delete the service file in /etc/systemd
  #
  # [*content*]
  #    The content of the service definition file in /etc/systemd
  #    as a string
  #
  # [*start*]
  #    Only useful for services. Either true, false, or undef
  #    (meaning started / stopped status is not managed).
  #
  # [*enable*]
  #    Either true, false, or undef (meaning enabled /
  #    disabled status is not managed)
  #
  # [*mask*]
  #    Either true, false, or undef (meaning masked /
  #    unmasked status is not managed)
  define unit (
    $ensure = undef,
    $content = undef,
    $enable = undef,
    $start = undef,
    $mask = undef
  ) {
    include ::systemd
  
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

    anchor { "systemd::unit_${name}::reloaded": }

    $_systemd_unit_file = "/etc/systemd/${_subdir}/${name}"

    if ($ensure == "absent") {
      file { $_systemd_unit_file:
        ensure => "absent"
      } ~>
      Exec['systemctl-daemon-reload'] ~>
      Anchor["systemd::unit_${name}::reloaded"]
    }
    elsif ($mask != undef and $mask) {
      exec { "Masking systemd ${name}":
        command => "systemctl mask ${name}",
        unless => "test $(systemctl is-enabled ${name} 2>/dev/null) = 'masked'",
        path => $::path
      } ~> Anchor["systemd::unit_${name}::reloaded"]
    } elsif ($content != undef or ($mask != undef and ! $mask)) {
      exec { "Unmasking systemd ${name}":
        command => "systemctl unmask ${name}",
        onlyif => "test $(systemctl is-enabled ${name} 2>/dev/null) = 'masked'",
        path => $::path
      }
      if ($content != undef) {
        Exec["Unmasking systemd ${name}"] ->
        file { $_systemd_unit_file:
          content => $content
        } ~>
        Exec['systemctl-daemon-reload'] ~>
        Anchor["systemd::unit_${name}::reloaded"]
      } else {
        Exec["Unmasking systemd ${name}"] ~>
        Anchor["systemd::unit_${name}::reloaded"]
      }
    }

    if ($enable == undef) {
      if ($mask == undef) {
        $_do_enable = $_kind == "service"
      }
    } else {
      $_do_enable = $enable
    }
  
    if ($_do_enable) {
      exec { "Enabling systemd ${name}":
        command => "systemctl enable ${name}",
        path => $::path,
        unless => "test $(/usr/bin/systemctl is-enabled ${name}) = 'enabled'"
      }
    } elsif ($enable != undef and ! $enable) {
      exec { "Disabling systemd ${name}":
        command => "systemctl disable ${name}",
        path => $::path,
        unless => "test $(/usr/bin/systemctl is-enabled ${name}) = 'disabled'"
      }
    }

    if ($kind == "service") {
      if ($start == undef) {
        Anchor["systemd::unit_${name}::reloaded"] ~>
        exec { "Reloading systemd ${name}":
          command => "systemctl reload-or-try-restart ${name}",
          path => $::path
        }
      } elsif ($start) {
        Anchor["systemd::unit_${name}::reloaded"] ~>
        exec { "Restarting systemd ${name}":
          command => "systemctl reload-or-restart ${name}",
          path => $::path,
          refreshonly => true
        } ->
        exec { "Starting systemd ${name}":
          command => "systemctl reload-or-restart ${name}",
          path => $::path,
          unless => "test $(systemctl is-active ${name}) = 'inactive'"
        }
      } else {
        exec { "Stopping systemd ${name}":
          command => "systemctl stop ${name}",
          path => $::path,
          unless => "test $(systemctl is-active ${name}) = 'inactive'"
        }
      }
    }  # if ($kind == "service")
  }  # define unit
}
