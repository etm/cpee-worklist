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

$sockets = []

class Echo < Riddl::WebSocketImplementation #{{{
  def onopen
    $sockets << self
    p "Connection established" # you need to pronounce it in french
  end

  def onclose
    $sockets.delete(self)
    p "Connection closed"
  end
end #}}} 

class Callbacks < Riddl::Implementation #{{{
  def response
    p @h
    @a[0] << (activity = {}) 
    activity['url'] = @h['CPEE_CALLBACK']
    activity['id']  = @h['CPEE_CALLBACK'].split('/').last
    activity['orgmodel'] = @h[ 'CPEE_ATTR_' + @p.shift.value.upcase]
    activity['domain'] = @p.shift.value
    activity['form'] = @p.shift.value
    activity['unit'] = @p.first.name == 'unit' ? @p.shift.value : '*'
    activity['role'] = @p.first.name == 'role' ? @p.shift.value : '*'
    activity['parameters'] = JSON.generate(@p)

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
    $sockets.each{ |s| s.send("Tu was, Motherfucker")}
  end
end  #}}} 

class Put_Away < Riddl::Implementation #{{{
  def response
    index = @a[0].index{ |c| c["id"] == @p[0].value }                                                 
    @a[0][index]["worker"] = "" if index
  end
end  #}}} 

class Show_Domains < Riddl::Implementation #{{{
  def response
    out = XML::Smart.string('<domains/>')
    @a[0].each { |e| e['domain'] }.uniq.each { |e| out.root.add('domain', :name=> e)}
    pp out.to_s
    Riddl::Parameter::Complex.new("return","xml/string", out.to_s)
  end
end  #}}}  

class Show_Domain_Users < Riddl::Implementation #{{{
  def response
    out = XML::Smart.string('<users/>')
    @a[0].map{ |e| e['orgmodel'] }.uniq.each do |e|
      x = XML::Smart.open(e)
      pp x.find('organisation')
    end
    @a[0].each { |e| out.root.add('domain', :name => e['domain'])}
    Riddl::Parameter::Complex.new("return","xml/string", out.to_s)
  end
end  #}}} 


Riddl::Server.new(::File.dirname(__FILE__) + '/worklist.xml', :port => 9299 ) do 
  accessible_description true
  cross_site_xhr true
  
  callbacks = []   
  at_exit do #{{{
    File.write File.dirname(__FILE__) + '/data/callbacks.sav', JSON.dump(callbacks)
  end #}}}
  callbacks = JSON.parse! File.read File.dirname(__FILE__) + '/data/callbacks.sav' rescue []
  on resource do
    run Callbacks,callbacks if post 'activity'
    run Show_Domains,callbacks if get '*' 
    on resource do
      run Show_Domain_Users,callbacks if get '*'
    end
    run Echo if websocket
    run Riddl::Utils::FileServe, ::File.dirname(__FILE__) + '/resources/worklist.html' if get '*'
    on resource 'resources' do #{{{
      on resource do
        run Riddl::Utils::FileServe, ::File.dirname(__FILE__) + '/resources' if get '*'
      end  
    end #}}}
    on resource 'callbacks' do #{{{
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
