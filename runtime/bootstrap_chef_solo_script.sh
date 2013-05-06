#!/bin/sh -e

server=$1

if [ "$user" = "" ]; then
  user="chef"
fi

if [ "$PROXY" != "" ]; then
  PROXY="http_proxy=$PROXY https_proxy=$PROXY"
fi

ssh $user@$server sudo mkdir -p /etc/chef/
current_folder=$(dirname $0)

scp $current_folder/../cookbooks/master_chef/templates/default/solo.rb $user@$server:/tmp/solo.rb
scp $current_folder/../cookbooks/master_chef/templates/default/rbenv_sudo_chef.sh $user@$server:/tmp/rbenv_sudo_chef.sh
ssh $user@$server sudo mv /tmp/solo.rb /etc/chef/solo.rb
ssh $user@$server sudo mv /tmp/rbenv_sudo_chef.sh /etc/chef/rbenv_sudo_chef.sh

scp ${current_folder}/default.json $user@$server:/tmp/default.json
ssh $user@$server sudo mv /tmp/default.json /etc/chef/local.json
ssh $user@$server sudo chmod +x /etc/chef/rbenv_sudo_chef.sh
ssh $user@$server GIT_CACHE_DIRECTORY=/var/chef/cache/git_repos $PROXY MASTER_CHEF_CONFIG=/etc/chef/local.json /etc/chef/rbenv_sudo_chef.sh -c /etc/chef/solo.rb
