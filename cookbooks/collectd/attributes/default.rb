default[:collectd][:plugins] = {
  "cpu" => {},
  "df" => {},
  "disk" => {},
  "entropy" => {},
  "interface" => {},
  "irq" => {},
  "memory" => {},
  "processes" => {},
  "swap" => {},
  "users" => {},
  "syslog" => {:config => "LogLevel \"info\""}
}
default[:collectd][:interval] = 10
default[:collectd][:config_directory] = "/etc/collectd/collectd.d"
default[:collectd][:python_plugin] = {
  :directory => "/opt/collectd/lib/collectd/plugins/python",
  :file => "/etc/collectd/collectd.d/python.conf"
}