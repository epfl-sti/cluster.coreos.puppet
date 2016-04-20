require 'logger'

$logger = Logger.new(STDERR)

Facter.value(:interfaces).split(',').each do |interface|
  ethtool_out = Facter::Core::Execution.exec("ethtool -P #{interface}")
  next if ! ethtool_out
  permanent_macaddr = ethtool_out.split(': ')[1]
  next if permanent_macaddr == "00:00:00:00:00:00"
  Facter.add("permanent_macaddress_#{interface}") do
    setcode do
      permanent_macaddr
    end
  end
end


