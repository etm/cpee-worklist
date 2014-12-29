#!/usr/bin/ruby

require 'riddl/client'
require 'json'
require 'pp'

client = Riddl::Client.new( 'http://localhost:9299/callbacks')
client.delete Riddl::Parameter::Simple.new "data","popo"
