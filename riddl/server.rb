#!/usr/bin/ruby
require 'pp'
require 'fileutils'
require 'rubygems'
require 'riddl/server'
require 'riddl/client'
require 'riddl/utils/notifications_producer'
require 'riddl/utils/properties'
require 'riddl/utils/fileserve'
require 'riddl/utils/downloadify'
require 'riddl/utils/turtle'

class  Callbacks < Riddl::Implementation #{{{
  def response
   pp @p
   result = {"url" => @h['CPEE_CALLBACK'], "form" => @p[0].value, "role" => @p[1].value} 
   @headers << Riddl::Header.new('CPEE_CALLBACK','true')
   @status = 200
  end
end  #}}} 

Riddl::Server.new(::File.dirname(__FILE__) + '/worklist.xml', :port => 9299) do
  accessible_description true
  cross_site_xhr true

  on resource do
    run Riddl::Utils::FileServe, ::File.dirname(__FILE__) + '/resources/worklist.html' if get '*'
    on resource 'resources' do
      on resource do
        run Riddl::Utils::FileServe, ::File.dirname(__FILE__) + '/resources' if get '*'
      end  
    end
    on resource 'callbacks' do
      run Callbacks if post 'callback_in'
    end
  end
end.loop!
