require 'logger'

if (! defined? Facter) then
  $TESTING = true
    class Facter
      def self.add(*unused)
      end
    end
else
  if (!defined? $TESTING) then
    $TESTING = false
  end
end

$logger = Logger.new(STDERR)

def snmpwalk(macaddr, switch_ip)
  ethernet_port_mib_base = "mib-2.17.7.1.2.2.1.2.1"
  ethernet_port_mib = ethernet_port_mib_base + "." + macaddr.split(":").map{|n| n.to_i(16).to_s(10)}.join(".")
  command = "snmpwalk -Os -c public -v 1 "+ switch_ip+" "+ethernet_port_mib
  snmpwalk_process = IO.popen(command)
  output_lines = snmpwalk_process.readlines
  Process.wait(snmpwalk_process.pid)
  if output_lines.empty? then
    $logger.error("Oops, no output lines")
    return
  end
  result = output_lines[0].split("INTEGER: ")[1].chomp().to_i(10)
  if result != 47 && result != 48 then return result end
end

if ($TESTING) then
  require("test/unit")

  class TestSimpleNumber < Test::Unit::TestCase

    def test_all
      @valid_mac = "CE:FB:63:35:84:F7"
      @bogus_mac = "CE:FB:63:35:84:F8"
      @expected_port = 6
      @expected_switch = "192.168.11.127"
      @another_switch = "192.168.11.126"

      assert_equal(@expected_port, snmpwalk(@valid_mac, @expected_switch))
      assert_equal(nil , snmpwalk(@bogus_mac, @expected_switch))
      assert_equal(nil , snmpwalk(@valid_mac, @another_switch))
    end
  end
end



$switch_ips = ["192.168.11.124", "192.168.11.125", "192.168.11.126", "192.168.11.127"]

Facter.add('switch_address') do
    macaddress = Facter.value(:macaddress_ethbr4)
    next if (! macaddress)
    value = nil
    for switch_ip in $switch_ips do
      port_nr = snmpwalk(macaddress, switch_ip)
      if port_nr then
        value = sprintf("%s:%d", switch_ip, port_nr)
      end
    end
    setcode do value end
end
