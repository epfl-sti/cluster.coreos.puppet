# Ceph facts

Facter.add('ceph_fsid') do
  ceph_conf = File.read("/opt/root/etc/ceph/ceph.conf")
  setcode do ceph_conf.match('fsid *= *(\S*)$')[1] end
end

