#!/bin/bash
if [ "$PROXY" != "" ]; then
	PROXY="http_proxy=$PROXY https_proxy=$PROXY"
fi

if [ "$MASTER_CHEF_URL" = "" ]; then
  # non standard url. rawgithub.com support http, raw.github.com does not
  MASTER_CHEF_URL="http://rawgithub.com/octo-technology/master-chef"
fi

if [ "$MASTER_CHEF_HASH_CODE" = "" ]; then
	MASTER_CHEF_HASH_CODE="master"
else
	MASTER_CHEF_FIRST_RUN="GIT_TAG_OVERRIDE=\"http://github.com/octo-technology/master-chef.git=$MASTER_CHEF_HASH_CODE\""
fi

print() {
	echo "/---------------------------------------------------------"
	echo "| $1"
	echo "\\---------------------------------------------------------"
}

print "Welcome into Master-Chef bootstraper !"

SUDO="sudo"
if [ "$USER" = "root" ]; then
	SUDO=""
else
	if ! $SUDO /bin/sh -c 'uname' > /dev/null; then
		echo "Cannot use sudo !"
		exit 1
	fi
fi

exec_command() {
	cmd="$*"
	sh -c "$cmd"
	if [ $? != 0 ]; then
		echo "Exection failed : $cmd"
		exit 2
	fi
}

exec_command_chef() {
	cmd="$*"
	sh -c "$SUDO sudo -H -u chef /bin/sh -c \"cd /home/chef && $cmd\""
	if [ $? != 0 ]; then
		echo "Execution failed for chef : $cmd"
		exit 2
	fi
}

install_master_chef_file() {
	file=$1
	target=$2
	url="$MASTER_CHEF_URL/$MASTER_CHEF_HASH_CODE/$file"
	echo "Downloading $url to $target"
	exec_command "$SUDO $PROXY curl -f -s -L $url -o $target"
}

install_master_chef_shell_file() {
	install_master_chef_file $1 $2
	exec_command "$SUDO chmod +x $2"
}
#exec_command "groupadd admin"
exec_command "cat /etc/passwd | grep ^chef > /dev/null || $SUDO useradd -m -g admin -s /bin/bash chef"
exec_command "$SUDO cat /etc/sudoers | grep ^chef > /dev/null || $SUDO /bin/sh -c 'echo \"chef   ALL=(ALL) NOPASSWD:ALL\" >> /etc/sudoers'"
exec_command "$SUDO cat /etc/sudoers | grep ^chef > /dev/null || $SUDO /bin/sh -c 'echo \"chef   ALL=(ALL) NOPASSWD:ALL\" >> /etc/sudoers'"
exec_command "$SUDO mkdir -p /home/chef/.ssh/"

if [ "$USER" != "chef" ]; then
	KEYS="$HOME/.ssh/authorized_keys"
	if [ -f $KEYS ]; then
		print "Installing credentials to chef account from $KEYS"
		exec_command "$SUDO cp $KEYS /home/chef/.ssh/authorized_keys"
	else
		echo "File not found $KEYS"
	fi
fi

exec_command "$SUDO chown -R chef /home/chef/.ssh"


print "Installing requirements for chef"
exec_command "$SUDO yum -y install git-core curl bzip2 sudo file libreadline5"
print "Base packaged installed ..."


if [ ! -f /tmp/chef-11.6.0-1.el6.x86_64.rpm ]
then
	exec_command "cd /tmp/ && wget --no-check-certificate https://opscode-omnibus-packages.s3.amazonaws.com/el/6/x86_64/chef-11.6.0-1.el6.x86_64.rpm"
	exec_command "$SUDO rpm -ivh /tmp/chef-11.6.0-1.el6.x86_64.rpm"
else
	print "Chef is already installed"
fi


# rvm
# ruby
# gem chef

exec_command "$SUDO mkdir -p /opt/master-chef/etc"
install_master_chef_file "cookbooks/master_chef/templates/default/solo.rb.erb" "/opt/master-chef/etc/solo.rb"
install_master_chef_file "runtime/local.json" "/opt/master-chef/etc/local.json"

print "Bootstraping master-chef"

exec_command_chef "VAR_CHEF=/opt/chef/var GIT_CACHE_DIRECTORY=/opt/master-chef/var/git_repos $PROXY $MASTER_CHEF_FIRST_RUN MASTER_CHEF_CONFIG=/opt/master-chef/etc/local.json sudo -E /opt/chef/bin/chef-solo -c /opt/master-chef/etc/solo.rb"

print "Master-chef Ready !!!!!!!"