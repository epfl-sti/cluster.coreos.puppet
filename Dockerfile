FROM alpine:3.1

# Puppet absolutely needs the shadow utils, such as useradd.
RUN echo http://dl-4.alpinelinux.org/alpine/edge/testing/ >> /etc/apk/repositories
RUN apk upgrade --update --available && \
    apk add \
      ca-certificates \
      openssl \
      curl \
      ruby \
      util-linux \
      shadow \
      ipmitool \
      dmidecode \
      ethtool \
      iptables \
      net-snmp-tools \
    && rm -f /var/cache/apk/* && \
    gem install -N \
      facter:'>= 2.4.3' \
      puppet:'= 3.8.1' \
    && rm -fr /root/.gem

# Shotgun-fix Puppet bug #7770
RUN cd /usr/lib/ruby/gems/*/gems/*/lib/puppet/provider/; \
    rm service/openrc.rb service/systemd.rb \
       package/gem.rb package/pip.rb

# selinux detection doesn't work well from inside Puppet
RUN cd /usr/lib/ruby/gems/*/gems/facter-*; \
    rm lib/facter/selinux.rb


ENV container docker
VOLUME ["/sys/fs/cgroup", "/run", "/var/lib/puppet", "/lib64"]

ENTRYPOINT ["/usr/bin/puppet"]
CMD ["help"]
