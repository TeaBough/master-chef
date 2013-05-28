
define :ssh_user_directory, {
  :action => :create
} do

  ssh_user_directory_params = params

  dir = "#{get_home ssh_user_directory_params[:name]}/.ssh"

  if find_resources_by_name("directory[#{dir}]")

    nil

  else

    directory dir do
      mode '0700'
      owner ssh_user_directory_params[:name]
      action ssh_user_directory_params[:action]

    end

    dir

  end

end