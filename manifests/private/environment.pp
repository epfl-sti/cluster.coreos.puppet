# Class: epflsti_coreos::private::environment
#
# Configure /etc/environment
#
# This class is intended to be loaded on all nodes.
#
# === Parameters:
#
# [*has_ups*]
#   Whether this host has an Uninterruptible Power Supply
#
# [*rootpath*]
#    Where in the Puppet-agent Docker container, the host root is
#    mounted
#
# === Global Variables and Facts:
#
# See ../templates/environment.erb
#
# === Actions:
#
# * Create /etc/environment
# * Alter the fleet configuration to set its public IP and metadata
# 

class epflsti_coreos::private::environment(
  $has_ups = $epflsti_coreos::private::params::has_ups,
  $rootpath = $epflsti_coreos::private::params::rootpath
) inherits epflsti_coreos::private::params {
    # Maintain /etc/environment for unit files to source host-specific data from
    concat { "/etc/environment":
      path => "$rootpath/etc/environment",
      ensure => "present"
    }

    concat::fragment { "machine-dependent /etc/environment":
      target => "/etc/environment",
      order => '10',
      content => template("epflsti_coreos/environment.erb")
    }

    file { ["${rootpath}/etc/bash", "${rootpath}/etc/bash/bashrc.d/"]:
      ensure => "directory"
    }

    concat { "/etc/bash/bashrc.d/source-etc-environment":
      path => "${rootpath}/etc/bash/bashrc.d/source-etc-environment",
      ensure => "present"
    }
    concat::fragment { "Header of /etc/bash/bashrc.d/source-etc-environment":
      target => "/etc/bash/bashrc.d/source-etc-environment",
      order => '0',
      content => template("epflsti_coreos/source-etc-environment.bash.erb")
    }

    define export_in_interactive_shell() {
      concat::fragment { "Export ${name} to interactive shell":
        target => "/etc/bash/bashrc.d/source-etc-environment",
        order => '50',
        content => "export ${name}\n"
      }
    }

    # Vanilla CoreOS 1185.3.0 has code in /etc/bash/bashrc to load all files
    # from /etc/bash/bashrc.d, but such code is not in 1068.10.0:
    if (! str2bool("$has_bashrc_d")) {
      $bashrc = "${rootpath}/etc/bash/bashrc"
      exec { "un-symlink ${bashrc}":
        command => "rm -f ${bashrc}; cp ${rootpath}/usr/share/bash/bashrc ${bashrc}",
        unless => "test -f ${bashrc} && ! test -h ${bashrc}",
        path => $::path
      } ->
      file_line { "source everything from /etc/bash/bashrc.d":
        path   => "${rootpath}/etc/bash/bashrc",
        ensure => 'present',
        # Present in vanilla CoreOS 1185.3.0, not in 1068.10.0:
          match  => "^for sh in /etc/bash/bashrc.d",
          line   => 'for sh in /etc/bash/bashrc.d/*; do [[ -r ${sh} ]] && source "${sh}"; done',
      }
    }
}
