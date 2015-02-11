#!/usr/bin/ruby
require 'pp'
require 'fileutils'
require 'rubygems'
require 'riddl/server'
require 'riddl/client'
require 'riddl/utils/notifications_producer'
require 'riddl/utils/fileserve'

$socket = []

class NotificationsHandler < Riddl::Utils::Notifications::Producer::HandlerBase #{{{
  def ws_open(socket)
    @data.add_websocket(@key,socket)
  end
  def ws_close
    @data.unserialize_notifications!(:del,@key)
    @data.notify('properties/handlers/change', :instance => @data.instance)
  end
  def ws_message(data)
    begin
      doc = XML::Smart::string(data)
      callback = doc.find("string(/vote/@id)")
      result = doc.find("string(/vote)")
      @data.callbacks[callback].callback(result == 'true' ? true : false)
      @data.callbacks.delete(callback)
    rescue
      puts "Invalid message over websocket"
    end
  end

  def create
    @data.unserialize_notifications!(:cre,@key)
    @data.notify('properties/handlers/change', :instance => @data.instance)
  end
  def delete
    @data.unserialize_notifications!(:del,@key)
    @data.notify('properties/handlers/change', :instance => @data.instance)
  end
  def update
    @data.unserialize_notifications!(:upd,@key)
    @data.notify('properties/handlers/change', :instance => @data.instance)
  end
end #}}}


def get_rel(orgmodels) #{{{
  rels = []
  orgmodels.each do |e|
    next if e == nil
    doc = XML::Smart.open(e)
    doc.register_namespace 'o', 'http://cpee.org/ns/organisation/1.0'
    doc.find("/o:organisation/o:subjects/o:subject[@uid='#{@r[-2]}']/o:relation").each{ |rel| rels << rel }
  end
  rels
end #}}}

def dl_xml(domain,url) #{{{
end #}}}

def write_callback(cb,domain) #{{{
  Thread.new do 
    File.write File.dirname(__FILE__) + "/data/domains/#{domain}/callbacks.sav", JSON.dump(cb)
  end  
end #}}}

class Callbacks < Riddl::Implementation #{{{
  def response
    activity = {}
    activity['label'] = "#{@h['CPEE_LABEL']} (#{@h['CPEE_INSTANCE'].split('/').last})"
    activity['user'] = '*'
    activity['url'] = @h['CPEE_CALLBACK']
    activity['id']  = @h['CPEE_CALLBACK'].split('/').last
    activity['orgmodel'] = @h[ 'CPEE_ATTR_' + @p.shift.value.upcase]
    activity['domain'] = @p.shift.value
    activity['form'] = @p.shift.value
    activity['unit'] = @p.first.name == 'unit' ? @p.shift.value : '*'
    activity['role'] = @p.first.name == 'role' ? @p.shift.value : '*'
    activity['parameters'] = JSON.generate(@p)

    @a[1][activity['domain']] = Riddl::Utils::Notifications::Producer::Backend.new(
       File.dirname(__FILE__) + "/topics.xml",
      File.dirname(__FILE__) + "/data/domains/#{activity['domain']}/notifications/"
    )
    status, content, headers = Riddl::Client.new(activity['orgmodel']).get
    if status == 200
      File.write(File.dirname(__FILE__) + "/data/orgmodels/" + Riddl::Protocols::Utils::escape(activity['orgmodel']), content[0].value.read)
      write_callback @a[0].callbacks << activity, activity['domain']
      @headers << Riddl::Header.new('CPEE_CALLBACK','true')
    else
      @status = 501
    end
  end
end #}}} 

class Delbacks < Riddl::Implementation #{{{
  def response
    index = @a[0].callbacks.index{ |e| e["id"] == @r.last }
    if index 
      domain = @a[0].callbacks[index]['domain']
      @a[0].callbacks.delete_at(index)
      write_callback @a[0].callbacks, domain
    else 
      @status = 404
    end
  end
end  #}}} 

class Show_Domains < Riddl::Implementation #{{{
  def response
    out = XML::Smart.string('<domains/>')
    @a[0].callbacks.map { |e| e['domain'] }.uniq.each { |x| out.root.add('domain', :name=> x)}
    Riddl::Parameter::Complex.new("return","text/xml") do
      out.to_s
    end
  end
end  #}}}  

class Show_Domain_Users < Riddl::Implementation #{{{
  def response
    out = XML::Smart.string('<users/>')
    fname = nil
    @a[0].callbacks.each{ |e| fname = e['orgmodel'] if e['domain'] == Riddl::Protocols::Utils::unescape(@r.last)}
    doc = XML::Smart.open(File.dirname(__FILE__) + "/data/orgmodels/#{Riddl::Protocols::Utils::escape(fname)}")
    doc.register_namespace 'o', 'http://cpee.org/ns/organisation/1.0'
    doc.find('/o:organisation/o:subjects/o:subject').each{ |e| out.root.add('user', :name => e.attributes['id'], :uid => e.attributes['uid'] ) }
    Riddl::Parameter::Complex.new("return","text/xml", out.to_s) 
  end
end  #}}} 

class Show_Tasks < Riddl:: Implementation #{{{
  def response
    out = XML::Smart.string('<tasks/>')
    tasks = {}
    pp @a[0].callbacks
    get_rel(@a[0].callbacks.map{ |e| e['orgmodel'] if e['domain']==Riddl::Protocols::Utils::unescape(@r[-3])}.uniq).each do |rel| 
      @a[0].callbacks.each do |cb| 
        if (cb['role']=='*' || cb['role'].casecmp(rel.attributes['role']) == 0) && (cb['unit'] == '*' || cb['unit'].casecmp(rel.attributes['unit']) == 0) && (cb['user']=='*' || cb['user']==@r[-2]) 
          tasks["#{cb['id']}"] = {:uid => cb['user'], :label => cb['label'] }
        end
      end
    end
    pp tasks
    tasks.each{|k,v| out.root.add("task", :id => k, :uid => v[:uid], :label => v[:label])}
    x = Riddl::Parameter::Complex.new("return","text/xml") do
      out.to_s
    end
    x
  end
end  #}}}  

class Take_Task < Riddl::Implementation #{{{
  def response
    pp "USER TAKE"
    pp @r[-3]
    index = @a[0].callbacks.index{ |c| c["id"] == @r.last }                                                 
    if index 
      @a[0].callbacks[index]["user"] = @r[-3]
      write_callback @a[0].callbacks, @a[0].callbacks[index]['domain']
    else
      @status = 404
    end
  end
end  #}}} 

class Return_Task < Riddl::Implementation #{{{
  def response
    pp "USER RETURN"
    pp @r[-3]
    index = @a[0].callbacks.index{ |c| c["id"] == @r.last }
    if index && (@a[0].callbacks[index]['user'] == @r[-3])
      @a[0].callbacks[index]["user"] = '*'
      write_callback @a[0].callbacks, @a[0].callbacks[index]['domain']
    else
      @stauts = 404
    end
  end
end  #}}} 

class Task_Details < Riddl::Implementation #{{{
  def response
    index = @a[0].callbacks.index{ |c| c["id"] == @r.last } 
    if index 
      [Riddl::Parameter::Simple.new("callbackurl", @a[0].callbacks[index]['url']), Riddl::Parameter::Simple.new("formurl", @a[0].callbacks[index]['form']), Riddl::Parameter::Simple.new("parameters", @a[0].callbacks[index]['parameters'])]
    else
      @status = 404
    end
  end
end  #}}} 

class Login < Riddl::Implementation #{{{
  def response
    pp @p[0]
  end
end  #}}} 

class JSON_Task_Details < Riddl::Implementation #{{{
  def response
    index = @a[0].callbacks.index{ |c| c["id"] == @r.last } 
    if index 
      Riddl::Parameter::Complex.new "data","application/json", JSON.generate({'url' => @a[0].callbacks[index]['url'], 'form' => @a[0].callbacks[index]['form'], 'parameters' => @a[0].callbacks[index]['parameters'], 'label' => @a[0].callbacks[index]['label']})
    else
      @status = 404
    end
  end
end  #}}} 

class Bla < Riddl::Implementation  #{{{
  def response 
    domain = r[:h]['RIDDL_DECLARATION_PATH'].split('/')[1].to_i
    user = r[:h]['RIDDL_DECLARATION_PATH'].split('/')[2].to_i
    p user
    p domain
  end
end #}}}

class Echo < Riddl::WebSocketImplementation #{{{
  def onopen
    $socket << self
    puts "Connection established"
  end

  def onmessage(data)
    printf("Received: %p\n", data)
    send data
    printf("Sent: %p\n", data)
  end

  def onclose
    $socket.delete(self)
    puts "Connection closed"
  end

end #}}}

class ControllerItem
  attr_accessor :callbacks, :notifications

  def initialize
    callbacks = []
    notifications = nil
  end

  def notify
  end
end

class Controller < Hash #{{{
  def initialize
    super
    Dir::glob(File.dirname(__FILE__) + '/data/domains/*').each do |f|
      f = File.basename(f)
      self[f] = ControllerItem.new
      self[f].callbacks = JSON.parse! File.read File.dirname(__FILE__) + "/data/domains/#{f}/callbacks.sav" rescue []
      self[f].notifications = Riddl::Utils::Notifications::Producer::Backend.new(
        File.dirname(__FILE__) + "/topics.xml",
        File.dirname(__FILE__) + "/data/domains/#{f}/notifications/"
      )
    end
  end
end #}}}

Riddl::Server.new(::File.dirname(__FILE__) + '/worklist.xml', :port => 9299 ) do 
  accessible_description true
  cross_site_xhr true

  controller = Controller.new
  interface 'main' do
    run Callbacks,controller if post 'activity'
    run Show_Domains,controller if get
    on resource do |r|
      domain = r[:h]['RIDDL_DECLARATION_PATH'].split('/')[1]
      domain = Riddl::Protocols::Utils::unescape(domain)

      run Show_Domain_Users,controller[domain] if get
      on resource do
        run Login if post 'session'
        on resource 'tasks' do
          run Show_Tasks,controller[domain] if get
          on resource do |r|
            run JSON_Task_Details,controller[domain] if get 'json_details'
            run Task_Details,controller[domain] if get
            run Take_Task,controller[domain] if put 'take'
            run Return_Task,controller[domain] if put 'giveback'
            run Delbacks,controller[domain] if delete
          end
        end
      end
    end
    # run Riddl::Utils::FileServe, ::File.dirname(__FILE__) + '/resources/worklist.html' if get '*'
    on resource 'resources' do #{{{
      on resource do
        run Riddl::Utils::FileServe, ::File.dirname(__FILE__) + '/resources' if get '*'
      end  
    end #}}}
  end

  interface 'events' do |r|
    domain = r[:h]['RIDDL_DECLARATION_PATH'].split('/')[1]
    domain = Riddl::Protocols::Utils::unescape(domain)
    use Riddl::Utils::Notifications::Producer::implementation(controller[domain].notifications, NotificationsHandler.new(nil))
  end

end.loop!
