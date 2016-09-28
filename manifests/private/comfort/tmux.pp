# Install tmux on all nodes
class epflsti_coreos::private::comfort::tmux(
  $rootpath = $::epflsti_coreos::private::params::rootpath)
inherits epflsti_coreos::private::params {
  $tmux_bin = "${rootpath}/opt/bin/tmux"
  $tmux_url = "https://github.com/epfl-sti/cluster.coreos.tmux/raw/master/tmux"
  exec { "curl for /opt/bin/tmux":
    command => "curl -L -o ${tmux_bin} ${tmux_url}",
    path => $::path,
    creates => $tmux_bin
  } ->
  file { "${tmux_bin}":
    owner => 'root',
    group => 'root',
    mode => '0755'
  }

  # Set up /dev/ptmx; only useful for ancient CoreOS (c35) afaict
  exec { "create $::ptmx_path":
    command => "set -e -x; rm $::ptmx_path; mknod $::ptmx_path c 5 2",
    path => $::path,
    unless => "test -c $::ptmx_path"
  } ->
  file { "$::ptmx_path":
    owner => 'root',
    group => 'tty',
    mode => '0666'
  }

  systemd::unit { "tmux-permanent.service":
    content => "[Unit]
Description=Permanent tmux sessions for user core (survive container death upon ssh exit)
[Service]
ExecStart=/opt/bin/tmux -C
User=core
Group=core
RemainAfterExit=yes
",
    enable => true,
    start => true
  }
}
