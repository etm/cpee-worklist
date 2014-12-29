#!/usr/bin/ruby

require 'riddl/client'
require 'json'
require 'pp'

client = Riddl::Client.new( 'http://localhost:9299/callbacks')
client.post [Riddl::Header.new('CPEE_CALLBACK','http://solo.wst.univie.ac.at/popo'),Riddl::Parameter::Simple.new("form", "form-c"),Riddl::Parameter::Simple.new("role","manager")]
