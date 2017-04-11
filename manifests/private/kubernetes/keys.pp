# Set up CA (Certification Authority) for Kubernetes
#
# Based on https://coreos.com/kubernetes/docs/latest/getting-started.html
#
# Just share keys with Puppet!
class epflsti_coreos::private::kubernetes::keys(
  $is_master = undef,
  $rootpath = $::epflsti_coreos::private::params::rootpath
) inherits epflsti_coreos::private::params {
  validate_bool($is_master)
  file { ["${rootpath}/etc/kubernetes", "${rootpath}/etc/kubernetes/ssl"]:
    ensure => "directory"
  }
  exec { "copy CA certificate":
    command => "cp /etc/puppet/ssl/certs/ca.pem ${rootpath}/etc/kubernetes/ssl/",
    path => $::path,
    creates => "${rootpath}/etc/kubernetes/ssl/ca.pem",
    require => File["${rootpath}/etc/kubernetes/ssl"]
  }
  if ($is_master) {
    exec { "copy API server key for Kubernetes":
      command => "cp -a /etc/puppet/ssl/private_keys/${::fqdn}.pem  ${rootpath}/etc/kubernetes/ssl/apiserver-key.pem",
      path => $::path,
      creates => ["${rootpath}/etc/kubernetes/ssl/apiserver-key.pem"],
      require => File["${rootpath}/etc/kubernetes/ssl"]
    }
    exec { "copy API server certificate for Kubernetes":
      command => "cp -a /etc/puppet/ssl/certs/${::fqdn}.pem  ${rootpath}/etc/kubernetes/ssl/apiserver.pem",
      path => $::path,
      creates => ["${rootpath}/etc/kubernetes/ssl/apiserver.pem"],
      require => File["${rootpath}/etc/kubernetes/ssl"]
    }
  } else {
    $worker_key_file = "${rootpath}/etc/kubernetes/ssl/${::fqdn}-worker-key.pem"
    $worker_cert_file = "${rootpath}/etc/kubernetes/ssl/${::fqdn}-worker.pem"
    $worker_combined_cert_and_key_file = "${rootpath}/etc/kubernetes/ssl/${::fqdn}-worker-key-and-cert.pem"
    exec { "copy agent key for worker Kubelet":
      command => "cp -a /etc/puppet/ssl/private_keys/${::fqdn}.pem  ${worker_key_file}",
      path => $::path,
      creates => $worker_key_file,
      require => File["${rootpath}/etc/kubernetes/ssl"]
    } ->
    file { $worker_key_file:
      owner => 0,    # root
      group => 500,  # core
      mode => "0640"
    }
    exec { "copy agent certificate and CA certificate for worker Kubelet":
      command => "cat /etc/puppet/ssl/certs/${::fqdn}.pem /etc/puppet/ssl/certs/ca.pem > $worker_cert_file",
      path => $::path,
      creates => $worker_cert_file,
      require => File["${rootpath}/etc/kubernetes/ssl"]
    } ->
    file { $worker_cert_file:
      owner => 0,  # root
      group => 0,  # root
      mode => "0644"
    }

    exec { "create combined cert and key file for haproxy":
      command => "cat /etc/puppet/ssl/certs/${::fqdn}.pem /etc/puppet/ssl/private_keys/${::fqdn}.pem > ${worker_combined_cert_and_key_file}",
      path => $::path,
      creates => $worker_combined_cert_and_key_file,
      require => File["${rootpath}/etc/kubernetes/ssl"]
    } ->
    file { $worker_combined_cert_and_key_file:
      owner => 0,    # root
      group => 500,  # core
      mode => "0640"
    }
}
}

