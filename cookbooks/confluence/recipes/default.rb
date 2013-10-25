include_recipe "mysql::server"
include_recipe "tomcat"
include_recipe "nginx"

[node.confluence.path.root_path, node.confluence.path.home, node.confluence.path.build].each do |dir|
  directory dir do
    owner node.tomcat.user
  end
end

mysql_database "confluence:database"

db_config = mysql_config "confluence:database"

Chef::Log.info "************************************************************"
Chef::Log.info "Mysql database for confluence"
Chef::Log.info "Host          : #{db_config[:host]}"
Chef::Log.info "Database name : #{db_config[:database]}"
Chef::Log.info "User          : #{db_config[:username]}"
Chef::Log.info "Password      : #{db_config[:password]}"
Chef::Log.info "************************************************************"

tar_gz = "#{node.confluence.version}.tar.gz"
build_dir = "#{node.confluence.path.build}/confluence-#{node.confluence.version}"
execute "download confluence"  do
  user node.tomcat.user
  command "cd #{node.confluence.path.build} && curl -f -s --location #{node.confluence.url} -o #{tar_gz} && tar xzf #{tar_gz}"
  environment get_proxy_environment
  not_if "[ -d #{build_dir} ]"
end

directory "#{build_dir}/edit-webapp/WEB-INF/classes"  do
  owner node.tomcat.user
  recursive true
end

file "#{build_dir}/edit-webapp/WEB-INF/classes/confluence-init.properties" do
  owner node.tomcat.user
  content "confluence.home=#{node.confluence.path.home}"
end

target_war = tomcat_instance "confluence:tomcat" do
  war_location node.confluence.location
end

if node[:confluence][:crowd][:enabled]
  template "#{build_dir}/edit-webapp/WEB-INF/classes/atlassian-user.xml" do
    source "atlassian-user.xml.erb"
    notifies :restart, "service[confluence]"
  end

  template "#{build_dir}/edit-webapp/WEB-INF/classes/crowd-ehcache.xml" do
    source "crowd-ehcache.xml.erb"
    notifies :restart, "service[confluence]"
  end

  directory "#{build_dir}/edit-webapp/WEB-INF/lib/"
  
  remote_file "#{build_dir}/edit-webapp/WEB-INF/lib/crowd-integration-client-#{node[:confluence][:crowd][:connector_version]}.jar" do
   source "http://tech.xebialabs.com/nexus/content/groups/public/com/atlassian/crowd/crowd-integration-client/#{node[:confluence][:crowd][:connector_version]}/crowd-integration-client-#{node[:confluence][:crowd][:connector_version]}.jar"
   notifies :restart, "service[confluence]"
  end

  template "#{build_dir}/edit-webapp/WEB-INF/classes/crowd.properties" do
    source "crowd.properties.erb"
    variables ({
        :config => node[:confluence][:crowd]
      })
    notifies :restart, "service[confluence]"
  end

  template "#{build_dir}/edit-webapp/WEB-INF/classes/seraph-config.xml" do
    source "seraph-config.xml.erb"
    notifies :restart, "service[confluence]"
  end
end

execute_version "build confluence" do
  user node.tomcat.user
  command "cd #{build_dir} && sh build.sh clean && sh build.sh && cp dist/confluence-#{node.confluence.version}.war #{target_war}"
  version node.confluence.url
  file_storage "#{build_dir}/.confluence_build"
end

tomcat_confluence_http_port = tomcat_config("confluence:tomcat")[:connectors][:http][:port]

nginx_add_default_location "confluence" do
  content <<-EOF

  location #{node.confluence.location} {
    proxy_pass http://tomcat_confluence_upstream;
    proxy_read_timeout 600s;
    break;
  }

EOF
  upstream <<-EOF
  upstream tomcat_confluence_upstream {
  server 127.0.0.1:#{tomcat_confluence_http_port} fail_timeout=0;
}
  EOF
end
