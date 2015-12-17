/bin/true 
# This template is never written out to a file! Rather, it is passed to an exec {} shell.
# Mind the Puppet bait on the first line. There needs to be a space at the end of it.
exec > /tmp/docker_pull_puppet.log 2>&1
set -x
export PATH="<%= @rootpath %>"/usr/bin:$PATH
pullfrom="<%= @docker_registry_address %>/<%= @docker_puppet_image_name %>"
docker pull ${pullfrom}:latest
imagever=$(docker images -q ${pullfrom})
if [ -z "$imagever" ] ; then
  # "docker images -q" above doesn't work in newer dockers, is it a bug?
  imagever="$(docker images | grep "$pullfrom" | awk '{if ($2 == "latest") {print $3}}')"
fi
if [ -n "$imagever" ]; then
  echo cluster_coreos_puppet_latest="$imagever" > /etc/facter/facts.d/cluster_coreos_puppet_latest.txt
fi
exit 0

