# Set up CA (Certification Authority) for Kubernetes
#
# Based on https://coreos.com/kubernetes/docs/latest/getting-started.html
#
# Just share keys with Puppet!
class epflsti_coreos::private::kubernetes::keys(
    $rootpath = $::epflsti_coreos::private::params::rootpath
) inherits epflsti_coreos::private::params {
  file { ["${rootpath}/etc/kubernetes", "${rootpath}/etc/kubernetes/ssl"]:
    ensure => "directory"
  }
  exec { "copy CA certificate":
    command => "cp /etc/puppet/ssl/certs/ca.pem ${rootpath}/etc/kubernetes/ssl/",
    path => $::path,
    creates => "${rootpath}/etc/kubernetes/ssl/ca.pem",
    require => File["${rootpath}/etc/kubernetes/ssl"]
  }

  file { "${rootpath}/etc/kubernetes/ssl/apiserver-key.pem":
    content => inline_template('<%= sprintf("%s-----%s-----\n%s\n-----%s-----\n" , *(@kubernetes_apiserver_private_key.split(/-+/))) %>'),
    owner => "root",
    group => "root",
    mode => "0600"
  }
  file { "${rootpath}/etc/kubernetes/ssl/apiserver.pem":
    content => $::kubernetes_apiserver_certificate,
    owner => "root",
    group => "root",
    mode => "0644"
  }
}

