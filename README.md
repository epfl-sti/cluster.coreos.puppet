Puppet on CoreOS
================

[![](https://badge.imagelayers.io/epflsti/puppet.svg)](https://imagelayers.io/?images=epflsti/puppet:latest 'View image size and layers')

Project URL: https://github.com/epflsti/cluster.coreos.puppet

Based on: https://github.com/jumanjihouse/puppet-on-coreos

Docker registry: https://registry.hub.docker.com/u/epflsti/puppet/


Overview
--------

Run Puppet inside a container such that it may affect the state
of the underlying CoreOS host.

Support for collecting IPMI facts included.


Wat? Why?
---------

Cloud-init is fine for bootstrapping CoreOS hosts, but sometimes you want to:

* consolidate inventory data (facter facts) in PuppetDB for all your hosts
* use a single cloud-config for all CoreOS hosts, then
  use Puppet to make minor config changes in an idempotent manner


How-to
------

Build image:

    docker build -t epflsti/puppet .

Upload image:

    docker push epflsti/puppet


License
-------

See [LICENSE](LICENSE) in this git repo.
