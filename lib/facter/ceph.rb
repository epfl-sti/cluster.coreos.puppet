# Ceph facts

begin
  ceph_conf = File.read("/opt/root/etc/ceph/ceph.conf")
  Facter.add('ceph_fsid') do
    setcode do ceph_conf.match('fsid *= *(\S*)$')[1] end
  end
rescue Errno::ENOENT
end
