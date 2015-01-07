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


class Callbacks < Riddl::Implementation #{{{
  def response
    pp "HEADER"
    pp @h
    pp "PARAMS"
    pp @p
    @a[0] << @p.map{|p| [p.name,p.value]}.to_h.merge({
      "url" => @h['CPEE_CALLBACK'], 
      "id"  => @h['CPEE_CALLBACK'].split('/').last
    })
    @headers << Riddl::Header.new('CPEE_CALLBACK','true')
  end
end #}}} 

class Delbacks < Riddl::Implementation #{{{
  def response
    index = @a[0].index{ |e| e["id"] == @r.last }
    if index 
      @a[0].delete_at(index)
    else 
      @status = 404
    end
  end
end  #}}} 

class  Show_List < Riddl::Implementation #{{{
  def response
    if File.open(File.dirname(__FILE__) + '/data/user/worker.txt').each_line.any?{|line| line.include? @p[0].value }                      
      Riddl::Parameter::Complex.new "data", "application/json" ,JSON.generate(@a[0].select { |c| c["role"] == "worker"})
    elsif File.open(File.dirname(__FILE__) + '/data/user/clerk.txt').each_line.any?{|line| line.include? @p[0].value }
      Riddl::Parameter::Complex.new "data", "application/json" ,JSON.generate(@a[0].select { |c| c["role"] == "clerk" })
    elsif File.open(File.dirname(__FILE__) + '/data/user/admin.txt').each_line.any?{|line| line.include? @p[0].value }
      Riddl::Parameter::Complex.new "data", "application/json" , JSON.generate(@a[0])
    else
      return 401
    end

  end
end   #}}} 

class Take_Work < Riddl::Implementation #{{{
  def response
    index = @a[0].index{ |c| c["id"] == @p[1].value }                                                 
    @a[0][index]["worker"] = @p[0].value if index
  end
end  #}}} 

class Put_Away < Riddl::Implementation #{{{
  def response
    index = @a[0].index{ |c| c["id"] == @p[0].value }                                                 
    @a[0][index]["worker"] = "" if index
  end
end  #}}} 

Riddl::Server.new(::File.dirname(__FILE__) + '/worklist.xml', :port => 9299) do
  accessible_description true
  cross_site_xhr true
  
  callbacks = []   
  at_exit do #{{{
    File.write File.dirname(__FILE__) + '/data/callbacks.sav', JSON.dump(callbacks)
  end #}}}
  callbacks = JSON.parse! File.read File.dirname(__FILE__) + '/data/callbacks.sav' rescue []
  on resource do
    run Riddl::Utils::FileServe, ::File.dirname(__FILE__) + '/resources/worklist.html' if get '*'
    on resource 'resources' do #{{{
      on resource do
        run Riddl::Utils::FileServe, ::File.dirname(__FILE__) + '/resources' if get '*'
      end  
    end #}}}
    on resource 'callbacks' do #{{{
      run Callbacks,callbacks if post 'callback_in'
      run Show_List,callbacks if get '*'
      on resource do #{{{
        run Delbacks,callbacks if delete
      end #}}}
    end #}}}
    on resource 'working' do #{{{
      run Take_Work,callbacks if get 'start_work'
    end #}}}
    on resource 'unworking' do #{{{
      run Put_Away,callbacks if get 'str'
    end #}}}
  end
end.loop!
