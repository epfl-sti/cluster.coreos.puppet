# Configure Kubernetes and Helm
#
# Based on https://coreos.com/kubernetes/docs/latest/deploy-master.html
# and https://coreos.com/kubernetes/docs/latest/deploy-workers.html,
# except that we use Google's Kubelet-in-Docker instead of CoreOS'
# Kubelet-in-rkt.
#
# === Parameters:
#
# [*k8s_version*]
#    The version to install for kubectl and the Kubernetes system
#    workloads: apiserver, controller-manager etc. (from
#    quay.io/coreos/hyperkube)
#
# [*kubelet_version*]
#    The Kubelet version to install (from
#    gcr.io/google_containers/hyperkube-amd64, *not* the CoreOS-provided
#    rkt image that is lagging behind in terms of versions at the moment,
#    and doesn't work with "pure" Calico).
#
# [*kubernetes_masters*]
#    The list of hosts to treat as Kubernetes masters (i.e. where to
#    run API servers etc.)
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
# === Bootstrapping:
#
# This class does *not* configure or start the Kubelet. This is done
# in the epflsti_coreos::private::kubernetes::start_kubelet ancillary
# class, at production-ready" stage (see ../init.pp for details on
# what that is).

class epflsti_coreos::private::kubernetes(
  $k8s_version = "1.6.2",
  $kubelet_version = "1.7.0-alpha.3",
  $kubernetes_masters = keys(parseyaml($::quorum_members_yaml)),
  $services_ip_range = $::kubernetes_services_ip_range,
  $helm_install_script_url = "https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get",
  $helm_install_dir = "/opt/bin",
  $rootpath = $::epflsti_coreos::private::params::rootpath
) inherits epflsti_coreos::private::params {
  include ::epflsti_coreos::private::systemd
  $is_master = !empty(intersection([$::fqdn], $kubernetes_masters))
  $master_count = size($kubernetes_masters)
  $kube_quay_version = "v${k8s_version}_coreos.0"
  $kubeconfig_path = "/etc/kubernetes/kubeconfig.yaml"
  $_calico_cni_conf = "${rootpath}/etc/kubernetes/cni/net.d/10-calico.conf"

  concat::fragment { "Kubernetes stuff for /etc/environment (all nodes)":
      target => "/etc/environment",
      order => '20',
      content => inline_template("K8S_VERSION=<%= @k8s_version %>
KUBELET_VERSION=<%= @kubelet_version %>
")
  }

  $_kubectl_path = "${rootpath}/opt/bin/kubectl"
  exec { "Download kubectl":
    path => $::path,
    command => "wget -O ${_kubectl_path} http://storage.googleapis.com/kubernetes-release/release/v${k8s_version}/bin/linux/amd64/kubectl && chmod 755 ${_kubectl_path}",
    unless => "grep v${k8s_version} ${_kubectl_path}",
  }

  systemd::docker_service { "kubelet":
    description => "Kubelet in a box (Docker)",
    enable => true,
    # Not started yet; see kubernetes/start_kubelet.pp
    volumes => [ "/:/rootfs:ro",
                 "/sys:/sys:ro",
                 "/var/lib/docker:/var/lib/docker:rw",
                 "/var/lib/kubelet:/var/lib/kubelet:rw",
                 "/etc/kubernetes:/etc/kubernetes:ro",
                 "/etc/kubernetes/cni:/etc/cni:ro",
                 "/opt/cni/bin:/opt/cni/bin:ro",
                 "/var/run:/var/run:rw",
                 "/usr/sbin/modprobe:/usr/sbin/modprobe:ro",
                 "/lib/modules:/lib/modules:ro",
                 ],
    net => "host",
    pid => "host",
    privileged => true,
    image => "gcr.io/google_containers/hyperkube-amd64:v${kubelet_version}",
    args => inline_template("/hyperkube kubelet --containerized <% -%>
    \"--hostname-override=${::hostname}\" <% -%>
    --api-servers=http://127.0.0.1:8080 <% -%>
    --network-plugin=cni <% -%>
    --network-plugin-dir=/etc/cni/net.d <% -%>
    --cni-conf-dir=/etc/cni/net.d <% -%>
    --cni-bin-dir=/opt/cni/bin <% -%>
    <%- if @is_master -%>
     --register-schedulable=false  <% -%>
    <% else -%>
     --register-node=true <% -%>
     --kubeconfig=<%= @kubeconfig_path %> <% -%>
     --tls-cert-file=/etc/kubernetes/ssl/<%= @fqdn %>-worker.pem <% -%>
     --tls-private-key-file=/etc/kubernetes/ssl/<%= @fqdn %>-worker-key.pem <% -%>
    <%- end -%>
     --allow-privileged=true <% -%>
     --pod-manifest-path=/etc/kubernetes/manifests <% -%>
     --hostname-override=<%= @hostname -%>
     --cluster-dns=<%= @dns_vip -%>
     --cluster-domain=cluster.local"),
    subscribe => File[$_calico_cni_conf]
  }

  static_manifest { "kube-apiserver":
      enable => $is_master,
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
    - --apiserver-count=${master_count}
    - --allow-privileged=true
    - --service-cluster-ip-range=${services_ip_range}
    - --storage-backend=etcd2
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
  }  # static_manifest "kube-apiserver"


  ensure_resource("class", epflsti_coreos::private::quorum_proxy)
  epflsti_coreos::private::quorum_proxy::quorum_forward { "kubernetes-apiserver":
    mode => "http_to_https",
    port => 8080,
    target_port => 443
  }

  static_manifest { "kube-proxy":
      enable => true,  # "The Kubernetes network proxy runs on each node"
                       # (http://kubernetes.io/docs/admin/kube-proxy/)
      content => inline_template("apiVersion: v1
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
<%- if @is_master -%>
    - --master=http://127.0.0.1:8080
<%- else -%>
    - --kubeconfig=<%= @kubeconfig_path %>
<%- end -%>
    - --proxy-mode=iptables
    - --hostname-override=<%= @hostname %>
    securityContext:
      privileged: true
    volumeMounts:
    - mountPath: /etc/ssl/certs
      name: ssl-certs
      readOnly: true
<%- if ! @is_master -%>
    - mountPath: <%= @kubeconfig_path %>
      name: kubeconfig
      readOnly: true
    - mountPath: /etc/kubernetes/ssl
      name: etc-kube-ssl
      readOnly: true
<%- end -%>
  volumes:
  - name: ssl-certs
    hostPath:
      path: /usr/share/ca-certificates
<%- if ! @is_master -%>
  - name: kubeconfig
    hostPath:
      path: <%= @kubeconfig_path %>
  - name: etc-kube-ssl
    hostPath:
      path: /etc/kubernetes/ssl
<%- end -%>
")
  }

  # Remote access to API servers
  class { "epflsti_coreos::private::kubernetes::keys":
    is_master => $is_master
  }
  if (! $is_master) {
    file { "${rootpath}/${kubeconfig_path}":
      content => template("epflsti_coreos/kubeconfig.yaml.erb")
    }
    concat::fragment { "Kubernetes environment for worker nodes":
      target => "/etc/environment",
      order => '20',
      content => "KUBECONFIG=${kubeconfig_path}\n"
    }
  }

  # Run kube-scheduler in high availability
  static_manifest { "kube-scheduler":
      enable => $is_master,
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

  static_manifest { "kube-controller-manager":
    enable => $is_master,
    content => "
apiVersion: v1
kind: Pod
metadata:
  name: kube-controller-manager
  namespace: kube-system
spec:
  hostNetwork: true
  containers:
  - name: kube-controller-manager
    image: quay.io/coreos/hyperkube:${kube_quay_version}
    command:
    - /hyperkube
    - controller-manager
    - --master=http://127.0.0.1:8080
    - --leader-elect=true
    - --service-account-private-key-file=/etc/kubernetes/ssl/apiserver-key.pem
    - --root-ca-file=/etc/kubernetes/ssl/ca.pem
    resources:
      requests:
        cpu: 200m
    livenessProbe:
      httpGet:
        host: 127.0.0.1
        path: /healthz
        port: 10252
      initialDelaySeconds: 15
      timeoutSeconds: 15
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

  file { ["${rootpath}/etc/kubernetes/cni", "${rootpath}/etc/kubernetes/cni/net.d"] :
    ensure => "directory"
  } ->
  file { $_calico_cni_conf:
    content => inline_template('{
    "name": "calico",
    "type": "calico",
    "etcd_endpoints": "http://localhost:2379",
    "log_level": "DEBUG",
    "log_level_stderr": "DEBUG",
    "hostname": "<%= @hostname %>",
    "ipam": {
        "type": "calico-ipam",
        "assign_ipv4": "true",
        "assign_ipv6": "false" <%# Pending https://gitlab.epfl.ch/sti-it/ops.nemesis/issues/53 %>
    },
    "network": {
        "type": "calico"
    },
    "policy": {
        "type": "k8s"
    },
    "kubernetes": {
        "kubeconfig": "/etc/kubernetes/kubeconfig.yaml"
    }
}')
  }

  # Record a Kubernetes "manifest" (to run a pod or any other
  # Kubernetes object) as a file in /etc/kubernetes/manifests.
  #
  # This lets one run things on Kubernetes without having to issue
  # commands to an apiserver.
  define static_manifest (
    $enable = true,
    $content = undef,
    $rootpath = $::epflsti_coreos::private::params::rootpath
  ) {
    if ($enable) {
      validate_string($content);
    ensure_resource("file", ["${rootpath}/etc/kubernetes",
                             "${rootpath}/etc/kubernetes/manifests"],
                            { ensure => "directory" })
      file { "${rootpath}/etc/kubernetes/manifests/${name}.yaml":
        content => $content
      }
    } else {
      file { "${rootpath}/etc/kubernetes/manifests/${name}.yaml":
        ensure => "absent"
      }
    }
  }

  # Install Helm - https://github.com/kubernetes/helm/blob/master/docs/install.md
  exec { "Install Helm":
    command => "curl ${helm_install_script_url} | sed 's/tar xf/tar zxf/' | HELM_INSTALL_DIR=${rootpath}/${helm_install_dir} PATH=${rootpath}/${helm_install_dir}:\$PATH sh -x",
    path => $::path,
    creates => "${rootpath}/${helm_install_dir}/helm"
  }
}
