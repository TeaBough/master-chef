
define :execute_version, {
  :command => nil,
  :file_storage => nil,
  :user => "root",
  :version => "",
  :notifies => nil,
  :or_only_if => [false],
  :environment => {}
} do

  execute_version_params = params

  [:command, :file_storage].each do |s|
    raise "Please specify #{s} with execute_version" unless execute_version_params[s]
  end

  execute "execute #{execute_version_params[:name]}" do
    command "rm -f #{execute_version_params[:file_storage]} && su #{execute_version_params[:user]} -c '#{execute_version_params[:command]}' && echo #{execute_version_params[:version]} > #{execute_version_params[:file_storage]}"
    environment execute_version_params[:environment]
    only_if (execute_version_params[:or_only_if] + ["[ ! -f #{execute_version_params[:file_storage]} ]", "[ \"`cat #{execute_version_params[:file_storage]}`\" != \"#{execute_version_params[:version]}\" ]"]).join(' || ')
    notifies *execute_version_params[:notifies] if execute_version_params[:notifies]
  end

end