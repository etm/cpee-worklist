#!/usr/bin/ruby
require 'riddl/client'

srv = Riddl::Client.new('http://localhost:9302','http://localhost:9302/?riddl-description')
res = srv.resource("/Virtual%20Business%201/notifications/subscriptions/")
status, response = res.post [                                                                                                                                                                                    
  Riddl::Parameter::Simple.new("url","http://solo.wst.univie.ac.at"),
  Riddl::Parameter::Simple.new("topic","task"),
  Riddl::Parameter::Simple.new("events","add"),
]
