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
  #    Only useful for services. Either true, false, "oneshot" or undef
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
    if ($name =~ /\.(service)$/) {
      $_kind = "service"
      $_subdir = "system"
    } elsif ($name =~ /\.(network|netdev)$/) {
      $_kind = "network"
      $_subdir = "network"
    } elsif ($name =~ /\.(socket)$/) {
      $_kind = "socket"
      $_subdir = "system"
    } elsif ($name =~ /\.(timer)$/) {
      $_kind = "timer"
      $_subdir = "system"
    } else {
      fail("Cannot determine unit type for ${name}")
    }

    $_systemd_unit_file = "/etc/systemd/${_subdir}/${name}"

    if ($ensure == "absent") {
      $_do_enable = false
    } elsif ($enable == undef) {
      if ($mask == undef) {
        $_do_enable = $_kind == "service"
      }
    } else {
      $_do_enable = $enable
    }
  
    if ($::lifecycle_stage == "production") {
  
      anchor { "systemd::unit_${name}::reloaded": }
  
      exec { "systemctl-daemon-reload for ${name}":
        command => 'systemctl daemon-reload',
        path => $::path,
        refreshonly => true
      }
  
      if ($ensure == "absent") {
        file { $_systemd_unit_file:
          ensure => "absent"
        } ~>
        Exec["systemctl-daemon-reload for ${name}"] ~>
        Anchor["systemd::unit_${name}::reloaded"]
      }
      elsif ($mask != undef and $mask) {
        exec { "Masking systemd ${name}":
          command => "systemctl mask ${name}",
          unless => "test $(systemctl is-enabled ${name} 2>/dev/null) = 'masked'",
          path => $::path
        } ~> Anchor["systemd::unit_${name}::reloaded"] ->
        exec { "Resetting failure state of systemd ${name}":
          command => "systemctl reset-failed ${name}",
          onlyif => "systemctl is-failed --quiet ${name}",
          path => $::path
        }
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
          Exec["systemctl-daemon-reload for ${name}"] ~>
          Anchor["systemd::unit_${name}::reloaded"]
        } else {
          Exec["Unmasking systemd ${name}"] ~>
          Anchor["systemd::unit_${name}::reloaded"]
        }
      }
  
      if ($_do_enable) {
        Anchor["systemd::unit_${name}::reloaded"] ->
        exec { "Enabling systemd ${name}":
          command => "systemctl enable ${name}",
          path => $::path,
          unless => "systemctl is-enabled ${name} |grep -q -E 'enabled|static'"
        }
      } elsif ($enable != undef and ! $enable) {
        Anchor["systemd::unit_${name}::reloaded"] ->
        exec { "Disabling systemd ${name}":
          command => "systemctl disable ${name}",
          path => $::path,
          onlyif => "test $(/usr/bin/systemctl is-enabled ${name}) |grep -q -E 'enabled|static'"
        }
      }
  
      if ($_kind == "service" or $_kind == "timer") {
        if ($start == undef) {
          Anchor["systemd::unit_${name}::reloaded"] ~>
          exec { "Reloading systemd ${name}":
            command => "systemctl try-reload-or-restart ${name}",
            path => $::path,
            refreshonly => true
          }
        } elsif ($start == "oneshot") {
          Anchor["systemd::unit_${name}::reloaded"] ~>
          exec { "Reloading systemd one-shot ${name}":
            command => "systemctl start ${name}",
            path => $::path,
            refreshonly => true
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
            unless => "test $(systemctl is-active ${name}) = 'active'"
          }
        } else {
          exec { "Stopping systemd ${name}":
            command => "systemctl stop ${name}",
            path => $::path,
            onlyif => "test $(systemctl is-active ${name}) = 'active'"
          }
        }
      }  # if ($_kind == "service" or $_kind == "timer")
    } else {  # $::lifecycle_stage != "production"
    
      file { $_systemd_unit_file:
        content => $content
      }
      if ($_do_enable) {
        File[$_systemd_unit_file] ~>
        exec { "Enabling systemd ${name}":
          command => "systemctl enable ${name}",
          path => $::path,
          unless => "systemctl is-enabled ${name} |grep -q -E 'enabled|static'"
        }
      }
    }  # end if $::lifecycle_stage != "production"
  }    # define unit

  define docker_service(
    $description = "A Docker service",
    $args = "",
    $ensure = undef,
    $enable = undef,
    $start = undef,
    $mask = undef,
    $image = undef,
    $volumes = [],
    $env = [],
    $ports = [],
    $after = [],  # docker.service is implicit
    $requires = [],  # docker.service is implicit
    $privileged = undef,
    $pid = undef,
    $net = undef,
    $docker_opts = [],
    $restart_sec="60s") {
      validate_string($image)
      $_do_not_install = ($enable != undef and ! $enable)

      systemd::unit { "${title}.service":
        ensure => $ensure,
        enable => $enable,
        start => $start,
        mask => $mask,
        content => inline_template(
";; This service is managed by Puppet as Systemd::Unit[\"<%= @title %>\"]
[Unit]
Description=<%= @description %>
After=docker.service <%= @after.join ' ' %>
Requires=docker.service <%= @requires.join ' ' %>

[Service]
RestartSec=<%= @restart_sec %>
Restart=always
ExecStartPre=-/usr/bin/docker rm -f %n
ExecStop=/usr/bin/docker rm -f %n
ExecStartPre=-/usr/bin/docker pull <%= @image %>
ExecStart=/usr/bin/docker run --rm --name %n <% -%>
  <%- if @privileged -%>--privileged <% end -%>
  <%- if @net -%>--net=<%= @net %> <% end -%>
  <%- if @pid -%>--pid=<%= @pid %> <% end -%>
  <%- @docker_opts.each do |opt| -%><%= opt %> <% end -%>
  <%- @ports.each do |port| -%>-p <%= port %> <% end -%>
  <%- @volumes.each do |volume| -%>-v <%= volume %> <% end -%>
  <%- @env.each do |env| -%>-e \"<%= env %>\" <% end -%>
  <%= @image -%>
  <%= @args || '' %>

<% if (! @_do_not_install) %>
[Install]
WantedBy=multi-user.target
<% end %>
")
      }
    }
  
    
}
