#!/usr/bin/ruby
require 'pp'
require 'fileutils'
require 'rubygems'
require 'riddl/server'
require 'riddl/client'
require 'riddl/utils/notifications_producer'
require 'riddl/utils/fileserve'

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
    tasks = []

    get_rel(@a[0].map{ |e| e['orgmodel'] if e['domain']==@r[-3].gsub('%20',' ')}.uniq).each{ |rel| @a[0].each{ |cb| tasks << cb['id'] if (cb['role']=='*' || cb['role'].casecmp(rel.attributes['role']) == 0) && (cb['unit'] == '*' || cb['unit'].casecmp(rel.attributes['unit']) == 0) && (cb['user']=='*' || cb['user']==@r[-2]) }}
    tasks.uniq.each{|e| next if e==nil;out.root.add("task", :id => e)}
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
    else
      @status = 404
    end
  end
end  #}}} 

class Return_task < Riddl::Implementation #{{{
  def response
    index = @a[0].index{ |c| c["id"] == @r.last }
    if index && (@a[0][index]['user'] == @r[-3])
      @a[0][index]["user"] = '*'
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

Riddl::Server.new(::File.dirname(__FILE__) + '/worklist.xml', :port => 9299 ) do 
  accessible_description true
  cross_site_xhr true
  callbacks = []   
  at_exit do #{{{
    puts 'aaaaa'
    File.write File.dirname(__FILE__) + '/data/callbacks.sav', JSON.dump(callbacks)
    exit!
  end #}}}
  callbacks = JSON.parse! File.read File.dirname(__FILE__) + '/data/callbacks.sav' rescue []

  interface 'main' do
    run Callbacks,callbacks if post 'activity'
    run Show_Domains,callbacks if get
    on resource do
      run Show_Domain_Users,callbacks if get
      on resource do
        on resource 'tasks' do
          run Show_Tasks,callbacks if get
          on resource do
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
    domain = r[:h]['RIDDL_DECLARATION_PATH'].split('/')[1].to_i
    user = r[:h]['RIDDL_DECLARATION_PATH'].split('/')[2].to_i
    p user
    p domain
    # use Riddl::Utils::Notifications::Producer::implementation(controller[id].notifications, NotificationsHandler.new(controller[id]), opts[:mode])
  end

end.loop!
