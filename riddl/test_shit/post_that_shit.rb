#!/usr/bin/ruby

require 'riddl/client'
require 'json'
require 'pp'

client = Riddl::Client.new( 'http://localhost:9299/callbacks')
client.post [Riddl::Header.new('CPEE_CALLBACK','http://solo.wst.univie.ac.at/222'),Riddl::Parameter::Simple.new("form", "resources/form-f.html"),Riddl::Parameter::Simple.new("role","manager"),Riddl::Parameter::Simple.new("dasdasds","adadadad")]
