#!/usr/bin/ruby
require 'pp'
require 'json'
require 'rubygems'
require 'riddl/server'
require 'riddl/client'
require 'riddl/utils/notifications_producer'
require 'riddl/utils/properties'
require 'riddl/utils/fileserve'
require 'riddl/utils/downloadify'
require 'riddl/utils/turtle'

 class Texti < Riddl::Implementation #{{{
  def response
    Riddl::Parameter::Simple.new "data", "Das Auto ist leider ziemlich kaputt. Kaufen sie ein neues oder spielen sie lieber nur virtuell Mario Kart"
  end
end  #}}} 

Riddl::Server.new(::File.dirname(__FILE__) + '/vers.xml', :port => 9301) do 
  accessible_description true
  cross_site_xhr true

  on resource do
    run Flower if get '*'
  end
end.loop! 
