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
  $k8s_version = "1.4.3",
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

  $kube_quay_version = "v${k8s_version}_coreos.0"
  systemd::unit { "kubernetes.service":
      content => "[Unit]
Description=Kubernetes in a box (Docker)
After=docker.service calico-node.service calico-libnetwork.service
Requires=docker.service calico-node.service calico-libnetwork.service

[Service]
ExecStartPre=/usr/bin/mkdir -p /etc/kubernetes/manifests
ExecStartPre=/usr/bin/mkdir -p /var/log/containers

Environment=KUBELET_VERSION=${kube_quay_version}
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
  --hostname-override=${::fqdn} \
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

  if ($is_master) {
    file { "${rootpath}/etc/kubernetes/manifests":
      ensure => "directory"
    }
    file { "${rootpath}/etc/kubernetes/manifests/kube-apiserver.yaml":
      content => "apiVersion: v1
kind: Pod
metadata:
  name: kube-apiserver
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: kube-apiserver
    image: quay.io/coreos/hyperkube:${kube_quay_version}
    command:
    - /hyperkube
    - apiserver
    - --bind-address=0.0.0.0
    - --etcd-servers=http://${::ipaddress}:2379
    - --allow-privileged=true
    - --service-cluster-ip-range=172.16.0.0/16
    - --secure-port=443
    - --advertise-address=${::ipaddress}
    - --admission-control=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota
    - --tls-cert-file=/etc/kubernetes/ssl/apiserver.pem
    - --tls-private-key-file=/etc/kubernetes/ssl/apiserver-key.pem
    - --client-ca-file=/etc/kubernetes/ssl/ca.pem
    - --service-account-key-file=/etc/kubernetes/ssl/apiserver-key.pem
    - --runtime-config=extensions/v1beta1=true,extensions/v1beta1/networkpolicies=true
    ports:
    - containerPort: 443
      hostPort: 443
      name: https
    - containerPort: 8080
      hostPort: 8080
      name: local
    volumeMounts:
    - mountPath: /etc/kubernetes/ssl
      name: ssl-certs-kubernetes
      readOnly: true
    - mountPath: /etc/ssl/certs
      name: ssl-certs-host
      readOnly: true
  volumes:
  - hostPath:
      path: /etc/kubernetes/ssl
    name: ssl-certs-kubernetes
  - hostPath:
      path: /usr/share/ca-certificates
    name: ssl-certs-host
"
    }
    file { "${rootpath}/etc/kubernetes/manifests/kube-proxy.yaml":
      content => "apiVersion: v1
kind: Pod
metadata:
  name: kube-proxy
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: kube-proxy
    image: quay.io/coreos/hyperkube:${kube_quay_version}
    command:
    - /hyperkube
    - proxy
    - --master=http://127.0.0.1:8080
    - --proxy-mode=iptables
    securityContext:
      privileged: true
    volumeMounts:
    - mountPath: /etc/ssl/certs
      name: ssl-certs-host
      readOnly: true
  volumes:
  - hostPath:
      path: /usr/share/ca-certificates
    name: ssl-certs-host
"
    }
    file { "${rootpath}/etc/kubernetes/manifests/kube-scheduler.yaml":
      content => "apiVersion: v1
kind: Pod
metadata:
  name: kube-scheduler
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: kube-scheduler
    image: quay.io/coreos/hyperkube:${kube_quay_version}
    command:
    - /hyperkube
    - scheduler
    - --master=http://127.0.0.1:8080
    - --leader-elect=true
    livenessProbe:
      httpGet:
        host: 127.0.0.1
        path: /healthz
        port: 10251
      initialDelaySeconds: 15
      timeoutSeconds: 1
"
    }
  }  # $is_master

  file { ["${rootpath}/etc/kubernetes/cni", "${rootpath}/etc/kubernetes/cni/net.d"] :
    ensure => "directory"
  } ->
  file { "${rootpath}/etc/kubernetes/cni/net.d/10-calico.conf":
    content => "{
    \"name\": \"calico\",
    \"type\": \"flannel\",
    \"delegate\": {
        \"type\": \"calico\",
        \"etcd_endpoints\": \"localhost:2379\",
        \"log_level\": \"none\",
        \"log_level_stderr\": \"info\",
        \"hostname\": \"${::ipaddress}\",
        \"policy\": {
            \"type\": \"k8s\",
            \"k8s_api_root\": \"http://127.0.0.1:8080/api/v1/\"
        }
    }
}"
  }
}
