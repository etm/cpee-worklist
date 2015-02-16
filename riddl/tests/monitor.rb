#!/usr/bin/ruby
require 'riddl/client'

srv = Riddl::Client.new('http://localhost:9302','http://localhost:9302/?riddl-description')
res = srv.resource("/Virtual%20Business%201/notifications/subscriptions/")
status, response = res.get
sub = ''
XML::Smart.string(response[0].value.read) do |doc|
  doc.register_namespace "s",'http://riddl.org/ns/common-patterns/notifications-producer/1.0'
  doc.find('/s:subscriptions/s:subscription/@id').each do |ele|
    sub = ele.to_s
  end
end

view = srv.resource("/Virtual%20Business%201/notifications/subscriptions/#{sub}/ws/")
view.ws do |conn|
  conn.stream do |msg|
    puts "<#{msg}>"
  end
  conn.disconnect do
    EM::stop_event_loop
  end
end