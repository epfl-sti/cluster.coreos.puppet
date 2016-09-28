require 'logger'

$logger = Logger.new(STDERR)

Facter.add('ptmx_path') do
  setcode do
    ["/opt/root/dev/pts/ptmx", "/opt/root/dev/ptmx"].first { |f| File.exist?(f) }
  end
end
