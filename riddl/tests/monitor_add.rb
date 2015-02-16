#!/usr/bin/ruby
require 'riddl/client'

srv = Riddl::Client.new('http://localhost:9302','http://localhost:9302/?riddl-description')
res = srv.resource("/Virtual%20Business%201/notifications/subscriptions/")
status, response = res.post [                                                                                                                                                                                    
  Riddl::Parameter::Simple.new("topic","user"),
  Riddl::Parameter::Simple.new("events","take,giveback"),
]
