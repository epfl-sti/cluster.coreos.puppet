# cluster.coreos.puppet

[![](https://badge.imagelayers.io/epflsti/puppet.svg)](https://imagelayers.io/?images=epflsti/puppet:latest 'View image size and layers')

Puppet Docker image and configuration (manifests) to run a CoreOS
cluster, EPFL-STI style

Docker registry: https://registry.hub.docker.com/u/epflsti/puppet/

# Getting Started

1. Configure and run the Puppet master: see [cluster.foreman](https://github.com/epfl-sti/cluster.foreman)
2. Check out [`cluster.coreos.puppet`](https://github.com/epfl-sti/cluster.coreos.puppet) inside the [`cluster.foreman`](https://github.com/epfl-sti/cluster.foreman) Docker container:
    docker exec -it puppetmaster.mysubdomain.mydomain.com /bin/bash
    cd /etc/puppet/environments/production/modules
    git clone https://github.com/epfl-sti/cluster.coreos.puppet.git epflsti_coreos
3. Provision a couple of nodes from the Foreman interface; they should auto-integrate into the Puppet cluster.

# Development

Build the Puppet agent image with Docker:

    docker build -t epflsti/puppet .

Upload the image:

    docker push epflsti/puppet


# Why Puppet on CoreOS?

At EPFL-STI, we [provision bare metal with Foreman](https://github.com/epfl-sti/cluster.foreman). We are currently [infatuated with CoreOS](https://github.com/epfl-sti/cluster.foreman), which has its [`cloud-config.yaml`](https://coreos.com/os/docs/latest/cloud-config.html) system, but even they say right in that page that "[i]t is not intended to be a Chef/Puppet replacement".

In our CoreOS clusters, Puppet + Foreman integration provides us with the following benefits:
* End-to-end automation for node provisioning (i.e. installation and configuration), including [IPMI](https://en.wikipedia.org/wiki/Intelligent_Platform_Management_Interface), means you can treat nodes as [cattle, not pets](https://news.ycombinator.com/item?id=7311704)
* Assign IP addresses centrally for all use cases (in EPFL-STI clusters we use separate subnets for the following: IPMI for lifecycle management, RFC1918 IPv4 for privileged services, and routable IPv6 for tenants)
* Continuous (re)configuration: add or modify services without reinstalling / rebooting
* Specialized configuration of individual nodes when you really do need it: etcd quorum member, gateway node with the physical Ethernet connection to the outside world...
* Gather key facts (in particular MAC addresses, `dmidecode`d serial numbers) into Foreman's centralized database
* Poor man's monitoring: was the node at least alive in the last 30 minutes?

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
