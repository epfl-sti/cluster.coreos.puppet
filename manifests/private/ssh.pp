# Class: epflsti_coreos::private::ssh
#
# Configure ssh access to bare metal.
#
# Use public keys (no passwords) just like
# https://coreos.com/os/docs/latest/cloud-config.html#ssh_authorized_keys,
# except you can add / remove administrators without reinstalling the
# entire fleet.
#
# === Variables:
#
# [*rootpath*]
#    Where in the Puppet-agent Docker container, the host root is
#    mounted
#
# === Actions:
#
# * Update /home/core/.ssh/authorized_keys
#
# * Set sane /etc/ssh/ssh_config (steady-state only, not at bootstrap time)
#
class epflsti_coreos::private::ssh(
  $rootpath = $epflsti_coreos::private::params::rootpath
) inherits epflsti_coreos::private::params {
  file { "${rootpath}/home/core/.ssh/authorized_keys":
    ensure => "present",
    content => template("epflsti_coreos/ssh_authorized_keys.erb"),
    owner => 500,   # core - but from outside the Docker container
    group => 500    # core
  }
  file { "${rootpath}/etc/ssh/ssh_config":
    ensure => "file",
    content => template("epflsti_coreos/ssh_config.erb")
  }

  # Share all ssh keys across the cluster
  # http://serverfault.com/questions/391454/manage-ssh-known-hosts-with-puppet
  # Requires puppetdb

  define exported_sshkey(
    $type = undef,
    $key = undef
  ) {
    # "@@" means that that resource is a so-called "exported" resource
    # (marked as such in puppetdb). Query resources like so (from
    # the puppetmaster):
    #
    #   curl -k -v --cert /var/lib/puppet/ssl/certs/$(hostname -f).pem  \
    #     --key /var/lib/puppet/ssl/private_keys/$(hostname -f).pem \
    #     https://$(hostname -f):8081/v3/resources/Sshkey
    #
    @@sshkey { $name:
      host_aliases => [$::hostname, $::fqdn, $::ipaddress],
      ensure => present,
      type => $type,
      key  => $key
    }   
  }

  if ($lifecycle_stage == "production") {
    # Note: exported resource names may not contain spaces.
    exported_sshkey { "ssh-rsa-${::hostname}":
      type => "rsa",
      key => $sshrsakey
    }

    exported_sshkey { "ssh-dsa-${::hostname}":
      type => "dsa",
      key => $sshdsakey
    }

    exported_sshkey { "ssh-ed25519-${::hostname}":
      type => "ed25519",
      key => $sshed25519key
    }

    # Fetch all keys from all hosts!
    # http://serverfault.com/a/391467/109290
    Sshkey <<| |>>

    # Used by template("epflsti_coreos/shosts.equiv.erb") below:
    $ssh_keys = query_resources(false, '@@Sshkey')

    file { "/etc/ssh/shosts.equiv":
      ensure => "present",
      content => template("epflsti_coreos/shosts.equiv.erb")
    }

    file { "/etc/ssh/sshd_config":
      ensure => "file",  # Erase CoreOS-provided symlink
      content => template("epflsti_coreos/sshd_config.erb")
    }
    # No need to restart sshd, see
    # https://coreos.com/os/docs/latest/customizing-sshd.html
  }
}
