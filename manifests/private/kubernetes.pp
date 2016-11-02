# Configure Kubernetes
#
# Based on https://coreos.com/kubernetes/docs/latest/deploy-master.html
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

  systemd::unit { "kubernetes.service":
      content => "[Unit]
Description=Kubernetes in a box (Docker)
After=docker.service calico-node.service calico-libnetwork.service
Requires=docker.service calico-node.service calico-libnetwork.service

[Service]
ExecStartPre=/usr/bin/mkdir -p /etc/kubernetes/manifests
ExecStartPre=/usr/bin/mkdir -p /var/log/containers

Environment=KUBELET_VERSION=v${k8s_version}_coreos.0
Environment=\"RKT_OPTS=--volume modprobe,kind=host,source=/usr/sbin/modprobe \
  --mount volume=modprobe,target=/usr/sbin/modprobe \
  --volume lib-modules,kind=host,source=/lib/modules \
  --mount volume=lib-modules,target=/lib/modules \
  --volume var-log,kind=host,source=/var/log \
  --mount volume=var-log,target=/var/log \
  --volume dns,kind=host,source=/etc/resolv.conf \
  --mount volume=dns,target=/etc/resolv.conf\"

ExecStart=/bin/sh -x /usr/lib/coreos/kubelet-wrapper \
  --api-servers=http://127.0.0.1:8080 \
  --network-plugin-dir=/etc/kubernetes/cni/net.d \
  --network-plugin=cni \
  --register-schedulable=false \
  --allow-privileged=true \
  --config=/etc/kubernetes/manifests \
  --cluster-dns=${::dns_vip} \
  --cluster-domain=cluster.local

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
",
    enable => true,
    start => true,
    require => [ Anchor["systemd::unit_calico-node.service::reloaded"], Anchor["systemd::unit_calico-libnetwork.service::reloaded"] ]
  }

  $_kubectl_path = "${rootpath}/opt/bin/kubectl"
  exec { "Download kubectl":
    path => $::path,
    command => "wget -O ${_kubectl_path} http://storage.googleapis.com/kubernetes-release/release/v${k8s_version}/bin/linux/amd64/kubectl && chmod 755 ${_kubectl_path}",
    unless => "grep v${k8s_version} ${_kubectl_path}"
  }
}
