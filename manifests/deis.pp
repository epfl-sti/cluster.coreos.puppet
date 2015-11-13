# Class: epflsti_coreos::deis
#
# The Deis install docs, translated into Puppet
#
# The [Deis install
# process](http://docs.deis.io/en/latest/installing_deis/baremetal/) have
# AYBABTU nature in a sort of uncomfortably pleasant way. Since we already
# got CoreOS to bootstrap in our own way, we only want to keep the pieces
# that install Deis itself on top.

class epflsti_coreos::deis() {
  include ::systemd

  $rootpath = "/opt/root"
  file { ["${rootpath}/opt", "${rootpath}/opt/bin"] }
    ensure => "directory",
  }

  define opt_bin_script() {
    file { "${::epflsti_coreos::deis::rootpath}/opt/bin/${name}":
      mode => "0755",
      content => template("epflsti_coreos/deis/${name}.erb"),
      require => File["${::epflsti_coreos::deis::rootpath}/opt/bin"]
    }
  }

  opt_bin_script {
    ["wupiao", "download-k8s-binary", "deis-graceful-shutdown",
     "scheduler-policy.json", "deis-debug-logs"]:
  }

  if ($::lifecycle_stage != "bootstrap") {
    file { ["${rootpath}/run/deis", "${rootpath}/run/deis/bin"]:
      ensure => "directory",
    }
    define run_deis_bin_script() {
      file { "${::epflsti_coreos::deis::rootpath}/run/deis/bin/${name}":
        mode => "0755",
        content => template("epflsti_coreos/deis/${name}.erb"),
        require => File["${::epflsti_coreos::deis::rootpath}/run/deis/bin"]
      }
    }
    run_deis_bin_script { ["get_image", "preseed"]: }
  }

  file { "${rootpath}/etc/systemd/graceful-deis-shutdown.service":
    content => template('epflsti_coreos/deis/graceful-deis-shutdown.service.erb'),
  } -> Exec["systemctl-daemon-reload"]

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
}
