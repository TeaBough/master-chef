require File.join(File.dirname(__FILE__), '..', 'helper.rb')

class TestConf2 < Test::Unit::TestCase

  include VmTestHelper
  include WaitHelper

  def test_conf2
    @vm.run "[ -f /my_loop_device_1 ] || sudo dd if=/dev/zero of=/my_loop_device_1 bs=200M count=1"
    @vm.run "[ -f /my_loop_device_2 ] || sudo dd if=/dev/zero of=/my_loop_device_2 bs=20M count=1"
    @vm.run "[ -f /loop0_ok ] || (sudo losetup /dev/loop0 /my_loop_device_1 && sudo touch /loop0_ok)"
    @vm.run "[ -f /loop1_ok ] || (sudo losetup /dev/loop1 /my_loop_device_2 && sudo touch /loop1_ok)"

    @vm.upload_json "conf2.json"
    @vm.run_chef

    # check lvm
    @vm.run "mount | grep vg.storage-lv.data | grep '/jenkins' | grep ext4"
    @vm.run "mount | grep vg.test-lv.test | grep '/toto' | grep ext3"
    @vm.run "echo titi > /toto/tata"

    @http.get 80, "/jenkins/"
    @http.assert_last_response_code 401
    assert_equal @http.response['WWW-Authenticate'], "Basic realm=\"myrealm\", Basic realm=\"myrealm\""
    @http.get 80, "/jenkins/", 'test', 'mypassword'
    assert_not_equal @http.response.code.to_i, 401

    wait "Waiting jenkins init" do
      @http.get 80, "/jenkins/", 'test', 'mypassword'
      @http.assert_last_response_code 200
      @http.assert_last_response_body_regex /New Job/
    end

    @http.get 80, "/jenkins/pluginManager/installed", 'test', 'mypassword'
    @http.assert_last_response_code 200
    @http.assert_last_response_body_regex /Green Balls/

    # Check cron management
    # Check chef second run
    crons = @vm.capture("ls /etc/cron.d").split("\n")
    assert_true crons.include?("munin-update")
    @vm.run "sudo touch /etc/cron.d/a"
    @vm.run_chef
    new_crons = @vm.capture("ls /etc/cron.d").split("\n")
    assert_equal crons, new_crons
    @http.get 80, "/jenkins/", 'test', 'mypassword'
    @http.assert_last_response_code 200
    @http.assert_last_response_body_regex /New Job/

    # Check remove apache2 configuration file
    apache2_conf_file = @vm.capture("ls /etc/apache2/conf.d").split("\n")
    @vm.run "sudo touch /etc/apache2/conf.d/toDelete"
    @vm_run_chef
    new_apache2_conf_file = @vm.capture("ls /etc/apache2/conf.d").split("\n")
    assert_equal apache2_conf_file, new_apache2_conf_file

    # Check APR is loaded into tomcat
    catalina_out = @vm.capture("cat /var/log/tomcat/jenkins/catalina.out")
    assert_not_match /n production environments was not found/, catalina_out

    # Check multiple Java version
    java_version = @vm.capture("java -version 2>&1")
    assert_match /1.7.0_07/, java_version
    @http.get 80, "/jenkins/systemInfo", 'test', 'mypassword'
    @http.assert_last_response_code 200
    @http.gsub("<wbr>","").assert_last_response_body_regex /1\.7\.0_07/

    # testing ssh_accept_host_key
    @vm.run "ssh-keygen -F localhost"
  end

end