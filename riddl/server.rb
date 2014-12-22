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

class  Startup < Riddl::Implementation #{{{
  def response
    Riddl::Parameter::Complex.new "data","text/html", File.open('./public/worklist.html')
  end
end  #}}} 

class  ShowCSS < Riddl::Implementation #{{{
  def response
    Riddl::Parameter::Complex.new "data","text/css", File.open('./public/smart-green.css')
  end
end  #}}} 

class  Callbacks < Riddl::Implementation #{{{
  def response
   pp @p
   @headers << Riddl::Header.new('CPEE_CALLBACK','true')
   @status = 200
  end
end  #}}} 

Riddl::Server.new(::File.dirname(__FILE__) + '/worklist.xml', :port => 9299) do
  accessible_description true
  cross_site_xhr true

  on resource do
    run Startup if get '*'
    on resource 'smart-green.css' do
      run ShowCSS if get '*'
    end
    on resource 'callbacks' do
      run Callbacks if post 'callback_in'
    end
  end
end.loop!
