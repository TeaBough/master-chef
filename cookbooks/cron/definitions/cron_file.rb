
define :cron_file, {
  :content => nil
} do
  cron_file_params = params

  raise "Please specify content with cron_file" unless cron_file_params[:content]

  file "/etc/cron.d/#{cron_file_params[:name]}" do
    content cron_file_params[:content] + " \n\n"
    mode '0644'
    notifies :restart, "service[cron]"
  end

end