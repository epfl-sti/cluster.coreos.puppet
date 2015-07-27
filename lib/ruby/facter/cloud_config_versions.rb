Facter.add('coreos_cloudconfig_provision_version') do
  setcode do
    Facter::Core::Execution.exec("sed -ne '/provision.erb \$Id:/p' < /etc/coreos/cloud-config.yml | awk '{print $4}'")
  end
end

Facter.add('coreos_cloudconfig_snippet_version') do
  setcode do
    Facter::Core::Execution.exec("sed -ne '/coreos_cloudconfig.erb \$Id:/p' < /etc/coreos/cloud-config.yml | awk '{print $4}'")
  end
end

Facter.add('coreos_cloudconfig_provision_version_short') do
  setcode do
    Facter.value('coreos_cloudconfig_provision_version')[0, 8]
  end
end

Facter.add('coreos_cloudconfig_snippet_version_short') do
  setcode do
    Facter.value('coreos_cloudconfig_snippet_version')[0, 8]
  end
end
