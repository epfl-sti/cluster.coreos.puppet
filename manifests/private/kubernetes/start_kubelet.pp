# Start Kubelet
#
# === Bootstrapping:
#
# This class is meant to run at "production-ready" stage (see
# ../init.pp for details on what that is); this is to ensure that new
# nodes don't join the cluster in a half-configured state.
  
class epflsti_coreos::private::kubernetes::start_kubelet() {
  exec { "systemctl start kubelet.service":
    path => $::path,
    unless => "test $(systemctl is-active kubelet.service) = 'active'"
  }
}
