# Configure Kubernetes
#
# Based on http://kubernetes.io/docs/getting-started-guides/docker-multinode/master/
#
# === Parameters:
#
# [*k8s_version*]
#    The Kubernetes version to install.
#
# [*kubernetes_masters*]
#   A list of hostnames of Kubernetes masters.
#
# [*rootpath*]
#    Where in the Puppet-agent Docker container, the host root is
#    mounted
#
# === Declared Variables:
#
# [*is_master*]
#    Whether this is a Kubernetes master node.
#

class epflsti_coreos::private::kubernetes(
  $k8s_version = "1.4.5",
  $kubernetes_masters = $::epflsti_coreos::private::params::kubernetes_masters,
  $rootpath = $::epflsti_coreos::private::params::rootpath
) inherits epflsti_coreos::private::params {
  $is_master = !empty(intersection([$::fqdn], $kubernetes_masters))

  concat::fragment { "K8S_VERSION in /etc/environment":
      target => "/etc/environment",
      order => '20',
      content => inline_template("K8S_VERSION=${k8s_version}\n")
  }

  class { "epflsti_coreos::private::kubernetes::keys": }

  if ($is_master) {
    $_master_address = "localhost"
  } else {
    # Hmm. This is certainly sub-optimal in some way
    $_master_address = $kubernetes_masters[0]
  }

  systemd::unit { "hyperkube-master.service":
      content => "[Unit]
Description=Kubernetes master in a box (Docker)
After=docker.service
Requires=docker.service

[Service]
ExecStartPre=/bin/bash -c '/usr/bin/docker rm -f %n || true'
EnvironmentFile=/etc/environment
ExecStart=/usr/bin/docker run \
    --name %n \
    --volume=/:/rootfs:ro \
    --volume=/sys:/sys:ro \
    --volume=/var/lib/docker/:/var/lib/docker:rw \
    --volume=/var/lib/kubelet/:/var/lib/kubelet:rw \
    --volume=/var/run:/var/run:rw \
    --net=host \
    --privileged=true \
    --pid=host \
    gcr.io/google_containers/hyperkube-amd64:v${k8s_version} \
    /hyperkube kubelet \
        --allow-privileged=true \
        --api-servers=http://${_master_address}:8080 \
        --v=2 \
        --address=0.0.0.0 \
        --enable-server \
        --config=/etc/kubernetes/manifests-multi \
        --containerized
",
    start => true
  }

  $_kubectl_path = "${rootpath}/opt/bin/kubectl"
  exec { "Download kubectl":
    path => $::path,
    command => "wget -O ${_kubectl_path} http://storage.googleapis.com/kubernetes-release/release/v${k8s_version}/bin/linux/amd64/kubectl && chmod 755 ${_kubectl_path}",
    unless => "grep v${k8s_version} ${_kubectl_path}"
  }
}
