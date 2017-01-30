# Set up or tear down transparent forwarding on port 80 on a gateway node
# (depending on the setting of $enable)
#
# This template is never written out to a file! Rather, it is passed
# to an exec {} shell.
#
# Variables (set by caller by prepending text):
#
# $enabled
#   Either "true" or "false"; the desired state of the transparent proxy rules

exec >> /var/log/setup_transparent_proxy.sh.log 2>&1

set -e -x
date

custom_chain="epflsti-TRANSPARENT-CACHE"

setup_toplevel() {
    iptables -t nat -A PREROUTING -p tcp --dport 80 -j "$custom_chain"
}

teardown_toplevel() {
    iptables -t nat -D PREROUTING -p tcp --dport 80
}

# TODO: (re)create the entire chain in one atomic operation using
# iptables-restore, so as to stop caller from checking whether the
# chain already exists
setup_chain() {
    if ! iptables-save -t nat |grep -q ":$custom_chain"; then
        iptables -t nat -N "$custom_chain"
    fi
    (iptables-save -t nat | grep -vw COMMIT | \
     grep -ve "-A $custom_chain"
<% if @external_ipv4_address -%>
    echo "-A $custom_chain -d <%= @external_ipv4_address.split("/")[0] %> -j RETURN"
<% end -%>
    echo "-A $custom_chain -d <%= ipv4_network %> -j RETURN"
    echo "-A $custom_chain -p tcp -j REDIRECT --to 3129"
    echo "COMMIT"
    ) | iptables-restore
}

teardown_chain() {
    iptables -t nat -X "$custom_chain"
}

case "$enabled" in
    true)
        setup_chain
        setup_toplevel
        ;;
    false)
        teardown_toplevel || true
        teardown_chain || true
        ;;
esac

