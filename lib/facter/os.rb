# Override os.release.minor to jive with the CoreOS release scheme
#
# Before (get_operatingsystemminorrelease in
# facter/operatingsystem/linux.rb): split on dots (or possibly
# dashes), take whatever comes second
#
# After: tack on a ".0" (there doesn't seem to be any use for the
# patchlevel field of the CoreOS version at e.g.
# alpha.release.core-os.net)
#
Not a git repository
To compare two paths outside a working tree:
usage: git diff [--no-index] <path> <path>
# Expected result: Foreman creates an Operatingsystem object that has
# the proper minor version, so that we could install from it (although
# the channel e.g. "beta", as well as the provisioning templates,
# would still need to be added by hand)

require 'facter/operatingsystem/implementation'
require 'facter/operatingsystem/osreleaselinux'

module Facter
  module Operatingsystem
    def self.implementation(kernel = Facter.value(:kernel))
        Facter::Operatingsystem::CoreOS.new
    end
    class CoreOS < OsReleaseLinux
        def get_operatingsystemminorrelease
          super + ".0"
        end
    end
  end
end

