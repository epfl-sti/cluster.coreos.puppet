# Start Kubelet
#
# === Bootstrapping:
#
# This class is meant to run at "production-ready" stage (see
# ../init.pp for details on what that is); this is to ensure that new
# nodes don't join the cluster in a half-configured state.
  
class epflsti_coreos::private::kubernetes::start_kubelet(
  $is_master = $epflsti_coreos::private::kubernetes::is_master,
  $api_server_urls = $epflsti_coreos::private::kubernetes::api_server_urls,
  $kubeconfig_path = $epflsti_coreos::private::kubernetes::kubeconfig_path
) {
  systemd::unit { "kubelet.service":
      content => template("epflsti_coreos/kubelet.service.erb"),
    enable => true,
    start => true,
    require => [ Anchor["systemd::unit_calico-node.service::reloaded"], Anchor["systemd::unit_calico-libnetwork.service::reloaded"] ],
  }
}
