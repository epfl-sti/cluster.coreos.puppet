# Class: epflsti_coreos::tenant_networking
#
# Configure tenant IPv6-only networking.
#
# One IPv6 subnet is assigned per tenant, where they can do whatever they please.
# One bridge is set up per tenant on each host.
#
class epflsti_coreos::tenant_networking() {
  include epflsti_coreos::tenant_networking::tenant
  epflsti_coreos::tenant_networking::tenant { "core-consul":
    ipv6_subnet => "2001:620:61e:0101:0000::/80"
  }
}
