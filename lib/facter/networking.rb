# coding: utf-8
# permanent_macaddress_#{interface}
Facter.value(:interfaces).split(',').each do |interface|
  ethtool_out = Facter::Core::Execution.exec("ethtool -P #{interface} 2>/dev/null")
  next if ! ethtool_out
  permanent_macaddr = ethtool_out.split(': ')[1]
  next if permanent_macaddr == "00:00:00:00:00:00"
  Facter.add("permanent_macaddress_#{interface}") do
    setcode do
      permanent_macaddr
    end
  end
end

# gateway (from https://projects.puppetlabs.com/issues/12265)
Facter.add(:ipv4_gateway) do setcode "ip route | awk '/default/{print $3}'" end
