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
* manage static external IPs (including masquerading with iptables)

How-to
------

Build image:

    docker build -t epflsti/puppet .

Upload image:

    docker push epflsti/puppet

Check out [`cluster.coreos.puppet.manifests`](https://github.com/epfl-sti/cluster.coreos.puppet.manifests) inside the [`cluster.foreman`](https://github.com/epfl-sti/cluster.foreman) Docker container:

    docker exec -it puppetmaster.mysubdomain.mydomain.com /bin/bash
    cd /etc/puppet/environments/production/modules
    git checkout XXXTODOXXX

License
-------

See [LICENSE](LICENSE) in this git repo.
