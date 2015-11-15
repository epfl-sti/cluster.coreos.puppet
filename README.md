# cluster.coreos.puppet

Puppet configuration (manifests) to run a CoreOS cluster, EPFL-STI style

To check out [`cluster.coreos.puppet`](https://github.com/epfl-sti/cluster.coreos.puppet) inside the [`cluster.foreman`](https://github.com/epfl-sti/cluster.foreman) Docker container:

    docker exec -it puppetmaster.mysubdomain.mydomain.com /bin/bash
    cd /etc/puppet/environments/production/modules
    git clone https://github.com/epfl-sti/cluster.coreos.puppet.git epflsti_coreos

