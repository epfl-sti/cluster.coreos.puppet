# cluster.coreos.puppet

Puppet configuration (manifests) to run a CoreOS cluster, EPFL-STI style

To check out [`cluster.coreos.puppet`](https://github.com/epfl-sti/cluster.coreos.puppet) inside the [`cluster.foreman`](https://github.com/epfl-sti/cluster.foreman) Docker container:

    docker exec -it puppetmaster.mysubdomain.mydomain.com /bin/bash
    cd /etc/puppet/environments/production/modules
    git clone https://github.com/epfl-sti/cluster.coreos.puppet.git epflsti_coreos

# How it works

## Puppet-in-Docker

To run Puppet on CoreOS, we rely on two Docker images:

+ one for the Puppetmaster, which is actually bundled with Foreman
  inside the
  [`cluster.foreman`](https://github.com/epfl-sti/cluster.foreman)
  project,
+ and one for the Puppet agent (see `puppet-agent/Dockerfile` in this project).

As is customary for a number of CoreOS services, the Docker container
for the Puppet agent is run as a systemd service, and both the
container and the service are named identically (`puppet.service`).

## Two-Stage Bootstrap

In the standard deployment scenario,
[`cluster.foreman`](https://github.com/epfl-sti/cluster.foreman) and
[`cluster.coreos.install`](https://github.com/epfl-sti/cluster.coreos.install)
cooperate to run the Dockerized Puppet agent a first time after CoreOS
is installed on the node being provisioned, and before it reboots. At
this stage, Puppet is responsible for installing itself into the
on-disk system image so that it operates normally after reboot.

In order for the Puppet code to to distinguish the bootstrap and
steady-state stages, Puppet is passed an environment variable
`FACTER_lifecycle_stage=bootstrap`, which translates to
`$::lifecycle_stage == "bootstrap"` in the code. Puppet arranges to
run itself with `FACTER_lifecycle_stage=production` after reboot.

This two-stage setup is made necessary by the fact that before
rebooting, the provisioning host needs to transition from the
"building" to "built" states in Foreman; this is so that even if the
BIOS is still configured to boot through PXE, the pxelinux
configuration on Foreman's TFTP server will instruct the provisioned
host to boot from the local disk.

Not all Puppet classes are aware of `$::lifecycle_stage`; for those
that aren't, `manifests/init.pp` simply excludes them at bootstrap
time. See the comments at the top of the individual `manifests/*.pp`
files for more details.
