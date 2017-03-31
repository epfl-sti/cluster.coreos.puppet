# Ensure that the default route is right, or restart networkd
#
# Expected to be invoked *exactly once* by either networking.pp or gateway.pp
#
# Parameters:
class epflsti_coreos::private::networking::default_route(
  $default_route
) {
    exec { "Ensure we have ${default_route} as the default route":
      command => "true ; while route del default; do :; done",
      path => $path,
      unless => "/usr/bin/test \"$(/sbin/ip route | sed -n 's/default via \(\S*\) .*/\1/p')\" = \"${default_route}\"",
    } ~>
    exec { "restart networkd in host":
      command => $::lifecycle_stage ? {
        "production" => "/usr/bin/systemctl restart systemd-networkd.service",
        default => "/bin/true ; echo No-op at bootstrap time"
      },
      refreshonly => true,
      path => $::path
    }
}
