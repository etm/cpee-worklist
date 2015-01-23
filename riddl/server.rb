#!/usr/bin/ruby
require 'pp'
require 'fileutils'
require 'rubygems'
require 'riddl/server'
require 'riddl/client'
require 'riddl/utils/notifications_producer'
require 'riddl/utils/fileserve'

$socket = []

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

def write_cb(cb) #{{{
  thr = Thread.new { File.write File.dirname(__FILE__) + '/data/callbacks.sav', JSON.dump(cb) }
  thr.join
end #}}}

class Callbacks < Riddl::Implementation #{{{
  def response
    @a[0] << (activity = {}) 
    activity['user'] = '*'
    activity['url'] = @h['CPEE_CALLBACK']
    activity['id']  = @h['CPEE_CALLBACK'].split('/').last
    activity['orgmodel'] = @h[ 'CPEE_ATTR_' + @p.shift.value.upcase]
    activity['domain'] = @p.shift.value
    activity['form'] = @p.shift.value
    activity['unit'] = @p.first.name == 'unit' ? @p.shift.value : '*'
    activity['role'] = @p.first.name == 'role' ? @p.shift.value : '*'
    @a[1][activity['domain']] ||= {} 
    #Read xml file user = |xxx|
    @a[1][activity['domain']][xxx] =  Riddl::Utils::Notifications::Producer::Backend.new(
        File.dirname(__FILE__) + '/topics.xml',
        File.dirname(__FILE__) + '/notifications/'
    )

    activity['parameters'] = JSON.generate(@p)
    write_cb(@a[0])
    @headers << Riddl::Header.new('CPEE_CALLBACK','true')
  end
end #}}} 

class Delbacks < Riddl::Implementation #{{{
  def response
    index = @a[0].index{ |e| e["id"] == @r.last }
    if index 
      @a[0].delete_at(index)
      write_cb(@a[0])
    else 
      @status = 404
    end
  end
end  #}}} 

class Show_Domains < Riddl::Implementation #{{{
  def response
    out = XML::Smart.string('<domains/>')
    @a[0].map { |e| e['domain'] }.uniq.each { |x| out.root.add('domain', :name=> x)}
    Riddl::Parameter::Complex.new("return","text/xml") do
      out.to_s
    end
  end
end  #}}}  

class Show_Domain_Users < Riddl::Implementation #{{{
  def response
    out = XML::Smart.string('<users/>')
    @a[0].map{ |e| e['orgmodel'] if e['domain']==@r.last.gsub('%20',' ')}.uniq.each do |e| 
      if e == nil
        @status = 404
        next
      end
      doc = XML::Smart.open(e)
      doc.register_namespace 'o', 'http://cpee.org/ns/organisation/1.0'
      doc.find('/o:organisation/o:subjects/o:subject').each{ |e| out.root.add('user', :name => e.attributes['id'], :uid => e.attributes['uid'] ) }
    end
    Riddl::Parameter::Complex.new("return","text/xml", out.to_s) 
  end
end  #}}} 

class Show_Tasks < Riddl:: Implementation #{{{
  def response
    out = XML::Smart.string('<tasks/>')
    tasks = {}

    get_rel(@a[0].map{ |e| e['orgmodel'] if e['domain']==@r[-3].gsub('%20',' ')}.uniq).each do |rel| 
      @a[0].each do |cb| 
        if (cb['role']=='*' || cb['role'].casecmp(rel.attributes['role']) == 0) && (cb['unit'] == '*' || cb['unit'].casecmp(rel.attributes['unit']) == 0) && (cb['user']=='*' || cb['user']==@r[-2]) 
          tasks["#{cb['id']}"] = cb['user']
        end
      end
    end
    pp tasks
    tasks.each{|k,v| out.root.add("task", :id => k, :uid => v)}
    x = Riddl::Parameter::Complex.new("return","text/xml") do
      out.to_s
    end
    x
  end
end  #}}}  

class Take_Task < Riddl::Implementation #{{{
  def response
    index = @a[0].index{ |c| c["id"] == @r.last }                                                 
    if index 
      @a[0][index]["user"] = @r[-3]
      write_cb(@a[0])
    else
      @status = 404
    end
  end
end  #}}} 

class Return_Task < Riddl::Implementation #{{{
  def response
    index = @a[0].index{ |c| c["id"] == @r.last }
    if index && (@a[0][index]['user'] == @r[-3])
      @a[0][index]["user"] = '*'
      write_cb(@a[0])
    else
      @stauts = 404
    end
  end
end  #}}} 

class Task_Details < Riddl::Implementation #{{{
  def response
    index = @a[0].index{ |c| c["id"] == @r.last } 
    if index 
      [Riddl::Parameter::Simple.new("callbackurl", @a[0][index]['url']), Riddl::Parameter::Simple.new("formurl", @a[0][index]['form']), Riddl::Parameter::Simple.new("parameters", @a[0][index]['parameters'])]
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
    index = @a[0].index{ |c| c["id"] == @r.last } 
    if index 
      Riddl::Parameter::Complex.new "data","application/json", JSON.generate({'url' => @a[0][index]['url'], 'form' => @a[0][index]['form'], 'parameters' => @a[0][index]['parameters']})
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

Riddl::Server.new(::File.dirname(__FILE__) + '/worklist.xml', :port => 9299 ) do 
  accessible_description true
  cross_site_xhr true
  callbacks = []   
  notifications = {}
  at_exit do #{{{
    File.write File.dirname(__FILE__) + '/data/callbacks.sav', JSON.dump(callbacks)
  end #}}}
  callbacks = JSON.parse! File.read File.dirname(__FILE__) + '/data/callbacks.sav' rescue []

  interface 'main' do
    run Callbacks,callbacks if post 'activity'
    run Show_Domains,callbacks if get
    on resource do
      run Show_Domain_Users,callbacks if get
      on resource do
        run Login if post 'session'
        on resource 'tasks' do
          run Show_Tasks,callbacks if get
          on resource do
            run JSON_Task_Details,callbacks if get 'json_details'
            run Task_Details,callbacks if get
            run Take_Task,callbacks if put 'take'
            run Return_Task,callbacks if put 'giveback'
            run Delbacks,callbacks if delete
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

  interface 'notifications' do |r|
    domain = r[:h]['RIDDL_DECLARATION_PATH'].split('/')[1]
    user = r[:h]['RIDDL_DECLARATION_PATH'].split('/')[2]
    pp user
    p domain
    use Riddl::Utils::Notifications::Producer::implementation(notifications[domain][user], NotificationsHandler.new(nil))
  end

end.loop!
