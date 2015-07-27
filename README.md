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


Why?
----

At EPFL-STI, we [provision bare metal with Foreman](https://github.com/epfl-sti/cluster.foreman). We are currently [infatuated with CoreOS](https://github.com/epfl-sti/cluster.foreman.community-templates), which has its own configuration management philosophy based on [`cloud-config.yaml`](https://coreos.com/os/docs/latest/cloud-config.html), and [reinstalling a lot](https://coreos.com/using-coreos/updates/.

Still, we have a need for Puppet agents on the hosts to:
* populate the Foreman database and UI with facts, in particular the IPMI networking data (IP and MAC address of IPMI controller etc) which allows for one-click reinstalls (okay, more like five-click) from the Foreman Web UI;
* manage static external IPs

How-to
------

Build image:

    docker build -t epflsti/puppet docker/

Upload image:

    docker push epflsti/puppet

Run the image: done automatically as part of [cluster.foreman.community-templates](https://github.com/epfl-sti/cluster.foreman.community-templates)

Configure the Puppet master: see [cluster.coreos.puppet.manifests](https://github.com/epfl-sti/cluster.coreos.puppet.manifests)

License
-------

See [LICENSE](LICENSE) in this git repo.
