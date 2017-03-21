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
# === Bootstrapping:
#
# This class does *not* configure or start the Kubelet. This is done in ancillary
# class epflsti_coreos::private::kubernetes::kubelet_service, at "production-ready"
# stage (see ../init.pp for details on what that is).

class epflsti_coreos::private::kubernetes(
  $k8s_version = "1.5.4",
  $kubernetes_masters = $::epflsti_coreos::private::params::kubernetes_masters,
  $rootpath = $::epflsti_coreos::private::params::rootpath
) inherits epflsti_coreos::private::params {
  $is_master = !empty(intersection([$::fqdn], $kubernetes_masters))
  $master_count = size($kubernetes_masters)
  $kube_quay_version = "v${k8s_version}_coreos.0"
  $api_server_urls = inline_template('<%= @kubernetes_masters.map { |host| "https://#{host}/" }.join "," %>')
  $kubeconfig_path = "/etc/kubernetes/kubeconfig.yaml"
  # Quite unfortunately needed, pending resolution of https://github.com/kubernetes/kubernetes/issues/18174:
  $first_apiserver = inline_template('<%= @kubernetes_masters[0] %>')

  concat::fragment { "Kubernetes stuff for /etc/environment (all nodes)":
      target => "/etc/environment",
      order => '20',
      content => inline_template("K8S_VERSION=<%= @k8s_version %>
KUBELET_VERSION=<%= kube_quay_version %>
")
  }

  $_kubectl_path = "${rootpath}/opt/bin/kubectl"
  exec { "Download kubectl":
    path => $::path,
    command => "wget -O ${_kubectl_path} http://storage.googleapis.com/kubernetes-release/release/v${k8s_version}/bin/linux/amd64/kubectl && chmod 755 ${_kubectl_path}",
    unless => "grep v${k8s_version} ${_kubectl_path}",
  }

  kubelet_service { "kube-apiserver":
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
    - --service-cluster-ip-range=192.168.12.0/24
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
  }  # kubelet_service "kube-apiserver"

  kubelet_service { "kube-proxy":
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
  }  # kubelet_service "kube-proxy"

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
    epflsti_coreos::private::environment::export_in_interactive_shell{ "KUBECONFIG": }
  }

  # Run kube-scheduler in high availability
  kubelet_service { "kube-scheduler":
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
  file { ["${rootpath}/etc/kubernetes/cni", "${rootpath}/etc/kubernetes/cni/net.d"] :
    ensure => "directory"
  } ->
  file { "${rootpath}/etc/kubernetes/cni/net.d/10-calico.conf":
    # The CoreOS doc seems wrong here. Based on
    # http://docs.projectcalico.org/v2.0/getting-started/kubernetes/installation/integration
    # instead
    content => "{
    \"name\": \"calico\",
    \"type\": \"calico\",
    \"etcd_endpoints\": \"http://localhost:2379\",
    \"log_level\": \"none\",
    \"log_level_stderr\": \"info\",
    \"hostname\": \"${::hostname}\",
    \"ipam\": {
        \"type\": \"calico-ipam\"
    },
    \"network\": {
        \"type\": \"calico\"
    },
    \"policy\": {
      \"type\": \"k8s\",
      \"k8s_api_root\": \"http://127.0.0.1:8080/api/v1/\"
    },
    \"kubernetes\": {
        \"kubeconfig\": \"/etc/kubernetes/kubeconfig.yaml\"
    }
}"
  }

  define kubelet_service (
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
}
