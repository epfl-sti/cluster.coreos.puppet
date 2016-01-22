# Class: epflsti_coreos::deis
#
# The Deis install docs, translated into Puppet
#
# The [Deis install
# process](http://docs.deis.io/en/latest/installing_deis/baremetal/) have
# AYBABTU nature in a sort of uncomfortably pleasant way. Since we already
# got CoreOS to bootstrap in our own way, we only want to keep the pieces
# that install Deis itself on top.
#
# === Parameters:
#
# [*rootpath*]
#    Where in the Puppet-agent Docker container, the host root is mounted
#
# [*ensure*]
#    Either "present" or "absent"
#

class epflsti_coreos::private::deis(
  $rootpath = $epflsti_coreos::private::params::rootpath,
  $ensure = "present"
)
inherits epflsti_coreos::private::params {
  include ::epflsti_coreos::private::systemd

  define script(
    $in_subdir
  ) {
    file { "${::epflsti_coreos::private::deis::rootpath}${in_subdir}/${name}":
      mode => "0755",
      ensure => "file",
      content => template("epflsti_coreos/deis/${name}.erb"),
      require => File["${::epflsti_coreos::private::deis::rootpath}${in_subdir}"]
    }
  }
  

  if ($ensure == "absent") {
    ensure_resource('file',
        ["${rootpath}/run/deis", "${rootpath}/etc/deis",
         "${rootpath}/var/lib/deis"],
        {
          ensure => "absent",
          force => true
        })
    file { ["${rootpath}/opt/bin/deisctl", "${rootpath}/etc/deis-release"]:
     ensure => "absent"
    }
  } else {
    ensure_resource('file',
        ["${rootpath}/opt", "${rootpath}/opt/bin",
         "${rootpath}/run/deis", "${rootpath}/run/deis/bin"],
        {
          ensure => "directory"
        })

    script {
      ["wupiao", "download-k8s-binary", "deis-graceful-shutdown",
       "scheduler-policy.json", "deis-debug-logs"]:
         in_subdir => "/opt/bin"
    }

    script { ["get_image", "preseed"]: 
         in_subdir => "/run/deis/bin"
    }

    exec { "install deisctl":
      creates => "${rootpath}/opt/bin/deisctl",
      command => "wget -O - http://deis.io/deisctl/install.sh | chroot /opt/root /usr/bin/bash -s",
      path => $::path,
      require => File["${rootpath}/opt/bin"]
    } ~> exec { "create /etc/deis-release":
      command => "/bin/sh -c 'echo -n \"DEIS_RELEASE=v\"; ${rootpath}/opt/bin/deisctl --version' > ${rootpath}/etc/deis-release",
      path => $::path,
      refreshonly => true
    }
  }  # $ensure != "absent"

  private::systemd::unit { "graceful-deis-shutdown.service":
    content => $ensure ? {
     "absent" => undef,
     default  => template('epflsti_coreos/deis/graceful-deis-shutdown.service.erb')
    },
    ensure => $ensure ? {
     "absent" => "absent",
     default  => undef
    },
    start => false
  }
}
