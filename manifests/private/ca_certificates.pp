class epflsti_coreos::private::ca_certificates(
  $rootpath = $::epflsti_coreos::private::params::rootpath
) inherits epflsti_coreos::private::params {
    exec { "cp ${rootpath}/etc/puppet/ssl/certs/ca.pem ${rootpath}/etc/ssl/certs/puppetmaster.pem":
      path => $::path,
      creates => "${rootpath}/etc/ssl/certs/puppetmaster.pem"
    } ~>
    exec { "chroot ${rootpath} update-ca-certificates":
      path => $::path,
      refreshonly => true
    }
}
