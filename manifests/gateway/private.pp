class epflsti_coreos::gateway::private {
  class params {
    case $::interfaces {
      /enp1s0f1/: { $external_interface = "enp1s0f1" }
      /enp4s0f1/: { $external_interface = "enp4s0f1" }
      default: { $external_interface = undef }
    }
  }
}
