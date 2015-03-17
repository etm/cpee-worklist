#!/usr/bin/ruby
require 'riddl/client'
require 'pp'

srv = Riddl::Client.new('http://localhost:9302','http://localhost:9302/?riddl-description')
res = srv.resource("/Virtual%20Business%201/notifications/subscriptions/")
status, response = res.post [                                                                                                                                                                                    
  Riddl::Parameter::Simple.new("topic","task"),
  Riddl::Parameter::Simple.new("votes","add"),
]
sub = response[0].value

view = srv.resource("/Virtual%20Business%201/notifications/subscriptions/#{sub}/ws/")
view.ws do |conn|
  conn.stream do |msg|
    pp msg.to_s
    p '========'
    doc = XML::Smart::string(msg.to_s)
    cb = doc.find('string(/vote/callback)')
    conn.send_msg "<vote id='#{cb}'>stertzf9</vote>"
  end
  conn.disconnect do
    EM::stop_event_loop
  end
end
