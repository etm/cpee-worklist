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

at_exit do
  File.open(File.dirname(__FILE__) + '/data/callbacks.sav','w') do |file|
    JSON.dump($callbacks,file)
  end
end

class  Callbacks < Riddl::Implementation #{{{
  def response
    result = {"url" => @h['CPEE_CALLBACK'], "form" => @p[0].value, "role" => @p[1].value, "id" => @h['CPEE_CALLBACK'].split('/').last}
    for i in 2..(@p.length-1)
      result["param#{i}"] = @p[i].value
    end
    $callbacks[$callbacks.length] = result
    @headers << Riddl::Header.new('CPEE_CALLBACK','true')
    @status = 200
  end
end  #}}} 

Riddl::Server.new(::File.dirname(__FILE__) + '/worklist.xml', :port => 9299) do
  accessible_description true
  cross_site_xhr true
  
  $callbacks = []    #Global Variable, all callbacks in memory
  File.open(File.dirname(__FILE__) + '/data/callbacks.sav','r') do |file|
    $callbacks = JSON.parse!(file.read) rescue []
  end if File.exist?(File.dirname(__FILE__) + '/data/callbacks.sav')
  pp $callbacks
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
