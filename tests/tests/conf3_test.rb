require File.join(File.dirname(__FILE__), '..', 'helper.rb')
require 'json'

class TestConf3 < Test::Unit::TestCase

  include VmTestHelper
  include WaitHelper

  def test_conf3
    @vm.upload_json "conf3.json"
    @vm.run_chef

    @vm.run "ls -al /opt/kibana/shared/log | grep '/var/log/kibana'"

    # check redmine
    @http.get 80, "/redmine"
    @http.assert_last_response_code 200
    @http.assert_last_response_body_regex /Redmine/

    # check date
    date = @vm.capture("date -u && date").split("\n").map{|x| x =~ /^.*(\d\d:\d\d:\d\d).*$/; $1}
    assert_not_equal date[0], date[1]

    # check rails app restart
    @vm.run "sudo /etc/init.d/redmine restart"
    @http.get 80, "/redmine"
    @http.assert_last_response_code 200
    @http.assert_last_response_body_regex /Redmine/

    # wait elastic search
    wait "elastic search http port open", 60, 5 do
      @vm.run("sudo netstat -nltp | grep 127.0.0.1:9200")
    end

    # check kibana
    @vm.run "echo 'truc' >> /tmp/toto.log"

    total = -1

    wait "Waiting kibana ready with some data", 180, 5 do
      @http.get 80, "/api/search/eyJzZWFyY2giOiJhYmNkIiwiZmllbGRzIjpbXSwib2Zmc2V0IjowLCJ0aW1lZnJhbWUiOiI5MDAiLCJncmFwaG1vZGUiOiJjb3VudCIsInN0YW1wIjoxMzQ4MTgxNTE2MDk2fQ==?_=#{Time.now.to_i}"
      @http.assert_last_response_code 200
      json = JSON.parse @http.response.body
      total = json['hits']['total']
    end

    @vm.run "echo 'abcd' >> /tmp/toto.log"

    wait "Waiting data in kibana", 180, 5 do
      @http.get 80, "/api/search/eyJzZWFyY2giOiJhYmNkIiwiZmllbGRzIjpbXSwib2Zmc2V0IjowLCJ0aW1lZnJhbWUiOiI5MDAiLCJncmFwaG1vZGUiOiJjb3VudCIsInN0YW1wIjoxMzQ4MTgxNTE2MDk2fQ==?_=#{Time.now.to_i}"
      @http.assert_last_response_code 200
      json = JSON.parse @http.response.body

      assert_equal json['hits']['total'], total + 1
    end

    # check es mapping in nginx
    @http.get 80, "/_aliases"
    @http.assert_last_response_code 200
    json = JSON.parse @http.response.body
    assert json.keys.first.match /^logstash/

    # check kibana 3
    @http.get 80, "/kibana3/config.js"
    @http.assert_last_response_code 200
    @http.assert_last_response_body_regex /window.location.protocol/
    @http.assert_last_response_body_regex /window.location.hostname/

  end

end