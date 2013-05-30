
include_recipe "nodejs"
include_recipe "libzmq"

base_user node.node_logstash.user

warp_install node.node_logstash.user do
  nvm true
end

node.node_logstash.groups.each do |g|

  add_user_in_group node.node_logstash.user do
    group g
  end

end

directory node.node_logstash.config_directory

patterns_directories = ""
patterns_directories = "--patterns_directories #{node.node_logstash.patterns_directories.join(',')}" if node.node_logstash.patterns_directories.length > 0

Chef::Config.exception_handlers << ServiceErrorHandler.new("logstash", ".*logstash.*")

nodejs_app "logstash" do
  user node.node_logstash.user
  directory node.node_logstash.directory
  script "bin/node-logstash-agent"
  opts "--db_file #{node.node_logstash.directory}/shared/files.json --config_dir #{node.node_logstash.config_directory} --log_level #{node.node_logstash.log_level} #{patterns_directories}"
  directory_check ["#{node.node_logstash.directory}/current/node_modules"]
  check_start :max_delay => 10
end

git_clone "#{node.node_logstash.directory}/current" do
  reference node.node_logstash.version
  repository node.node_logstash.git
  user node.node_logstash.user
  notifies :restart, "service[logstash]"
end

file "#{node.node_logstash.directory}/current/.node_version" do
  owner node.node_logstash.user
  content node.node_logstash.node_version
end

execute_version "install node-logstash dependencies" do
  user node.node_logstash.user
  command "export HOME=#{get_home node.node_logstash.user} && cd #{node.node_logstash.directory}/current && rm -rf node_modules && $HOME/.warp/client/node/install.sh"
  version node.node_logstash.node_version + '_' + node.node_logstash.version
  environment get_proxy_environment
  file_storage "#{node.node_logstash.directory}/current/.npm_ready"
  notifies :restart, "service[logstash]"
end

if node.node_logstash[:configs]
  node.node_logstash.configs.each do |k, v|
    node_logstash_config k do
      urls v
    end
  end
end

if node.node_logstash[:monitor_files]
  node.node_logstash.monitor_files.each do |k, v|
    node_logstash_files k do
      files v['files']
      log_type v['type'] if v['type']
    end
  end
end

delayed_exec "Remove useless logstash config files" do
  after_block_notifies :restart, "service[logstash]"
  block do
    updated = false
    confs = find_resources_by_name_pattern(/^\/etc\/logstash.d\/.*$/).map{|r| r.name}
    Dir["/etc/logstash.d/*"].each do |n|
      unless confs.include? n
        Chef::Log.info "Removing config files #{n}"
        File.unlink n
        updated = true
      end
    end
    updated
  end
end
