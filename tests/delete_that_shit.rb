#!/usr/bin/ruby

require 'riddl/client'
require 'json'
require 'pp'

client = Riddl::Client.new( 'http://localhost:9299/callbacks/popo')
client.delete
