#!/usr/bin/ruby
require 'pp'
require 'fileutils'
require 'rubygems'
require 'riddl/server'
require 'riddl/client'
require 'riddl/utils/notifications_producer'
require 'riddl/utils/fileserve'

class NotificationsHandler < Riddl::Utils::Notifications::Producer::HandlerBase #{{{
  def ws_open(socket)
    @data.communication[@key] = socket
    @data.events.each do |a|
      if a[1].has_key?(@key)
        a[1][@key] = socket
      end  
    end
    @data.votes.each do |a|
      if a[1].has_key?(@key)
        a[1][@key] = socket
      end  
    end
  end
  def ws_close
    delete
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
    @data.notifications.subscriptions[@key].read do |doc|
      turl = doc.find('string(/n:subscription/@url)') 
      url = turl == '' ? nil : turl
      @data.communication[@key] = url
      doc.find('/n:subscription/n:topic').each do |t|
        t.find('n:event').each do |e|
          @data.events["#{t.attributes['id']}/#{e}"] ||= {}
          @data.events["#{t.attributes['id']}/#{e}"][@key] = (url == "" ? nil : url)
        end
        t.find('n:vote').each do |e|
          @data.votes["#{t.attributes['id']}/#{e}"] ||= {}
          @data.votes["#{t.attributes['id']}/#{e}"][@key] = (url == "" ? nil : url)
        end
      end
    end
   # @data.notify('properties/handlers/change', :instance => @data.instance)
  end
  def delete
    @data.notifications.subscriptions[@key].delete if @data.notifications.subscriptions.include?(@key)
    @data.communication[@key].io.close_connection if @data.communication[@key].class == Riddl::Utils::Notifications::Producer::WS                                                                                        
    @data.communication.delete(@key)

    @data.events.each do |eve,keys|
      keys.delete_if{|k,v| @key == k}
    end  
    @data.votes.each do |eve,keys|
      keys.delete_if do |k,v|
        if @key == k
          @data.callbacks.each{|voteid,cb|cb.delete_if!(eve,k)}
          true
        end  
      end
    end  
  end
  def update
    if @data.notifications.subscriptions.include?(@key)
      url = @data.communication[@key]
      evs = []
      vos = []
      @data.events.each { |e,v| evs << e }
      @data.votes.each { |e,v| vos << e }
      @data.notifications.subscriptions[@key].read do |doc|
        turl = doc.find('string(/n:subscription/@url)') 
        url = turl == '' ? url : turl
        @data.communication[@key] = url
        doc.find('/n:subscription/n:topic').each do |t|
          t.find('n:event').each do |e|
            @data.events["#{t.attributes['id']}/#{e}"] ||= {}
            @data.events["#{t.attributes['id']}/#{e}"][@key] = url
            evs.delete("#{t.attributes['id']}/#{e}")
          end
          t.find('n:vote').each do |e|
            @data.votes["#{t.attributes['id']}/#{e}"] ||= {}
            @data.votes["#{t.attributes['id']}/#{e}"][@key] = url
            vos.delete("#{t.attributes['id']}/#{e}")
          end
        end
      end
      evs.each { |e| @data.events[e].delete(@key) if @data.events[e] }
      vos.each do |e| 
        @data.callbacks.each{|voteid,cb|cb.delete_if!(e,@key)}
        @data.votes[e].delete(@key) if @data.votes[e]
      end  
    end  
  end
end #}}}

class ActivityHappens < Riddl::Implementation #{{{
  def response
    activity = {}
    activity['label'] = "#{@h['CPEE_LABEL']} (#{@h['CPEE_INSTANCE'].split('/').last})"
    activity['user'] = '*'
    activity['url'] = @h['CPEE_CALLBACK']
    activity['id']  = @h['CPEE_CALLBACK'].split('/').last
    activity['orgmodel'] = @h[ 'CPEE_ATTR_' + @p.shift.value.upcase]
    domain = activity['domain'] = @p.shift.value
    activity['form'] = @p.shift.value
    activity['unit'] = @p.first.name == 'unit' ? @p.shift.value : '*'
    activity['role'] = @p.first.name == 'role' ? @p.shift.value : '*'
    activity['parameters'] = JSON.generate(@p)
    status, content, headers = Riddl::Client.new(activity['orgmodel']).get
    if status == 200
      xml =  content[0].value.read
      @a[0].add_callback domain, activity
      @a[0][domain].add_orgmodel Riddl::Protocols::Utils::escape(activity['orgmodel']), xml
      xml =  XML::Smart.string(xml)
      xml.register_namespace 'o', 'http://cpee.org/ns/organisation/1.0'
      attributes = ""
      if activity['role'] != '*'
        attributes += "@role='#{activity['role']}'"
        attributes += " and " if activity['unit'] != '*'
      end
      attributes += "@unit='#{activity['unit']}'" if activity['unit'] != '*'
      user = xml.find("/o:organisation/o:subjects/o:subject[o:relation[#{attributes}]]").map{ |e| e.attributes['uid'] }
      @a[0][domain].notify('task/add', :user => user , :index => activity['id'], :instance => @h['CPEE_INSTANCE'].split('/').last, :base => @h['CPEE_BASE'])

      @headers << Riddl::Header.new('CPEE_CALLBACK','true')
    else
      @status = 501
    end
  end
end #}}} 

class TaskDel < Riddl::Implementation #{{{
  def response
    index = @a[0].activities.index{ |e| e["id"] == @r.last }
    if index 
      callback_id = @a[0].activities[index]['id']
      @a[0].activities.delete_at(index)
      @a[0].activities.serialize
      @a[0].notify('user/finish', :index => callback_id )
    else 
      @status = 404
    end
  end
end  #}}} 

class Show_Domains < Riddl::Implementation #{{{
  def response
    out = XML::Smart.string('<domains/>')
    @a[0].keys.each { |x| out.root.add('domain', :name=> x)}
    Riddl::Parameter::Complex.new("return","text/xml") do
      out.to_s
    end
  end
end  #}}}  

class Show_Domain_Users < Riddl::Implementation #{{{
  def response
    out = XML::Smart.string('<users/>')
    fname = nil
    @a[0].activities.each{ |e| fname = e['orgmodel'] if e['domain'] == Riddl::Protocols::Utils::unescape(@r.last)}
    doc = XML::Smart.open(File.dirname(__FILE__) + "/domains/#{Riddl::Protocols::Utils::unescape(@r.last)}/orgmodels/#{Riddl::Protocols::Utils::escape(fname)}")
    doc.register_namespace 'o', 'http://cpee.org/ns/organisation/1.0'
    doc.find('/o:organisation/o:subjects/o:subject').each{ |e| out.root.add('user', :name => e.attributes['id'], :uid => e.attributes['uid'] ) }
    Riddl::Parameter::Complex.new("return","text/xml", out.to_s) 
  end
end  #}}} 

class Show_Tasks < Riddl:: Implementation #{{{
  def response
    out = XML::Smart.string('<tasks/>')
    tasks = {}
    @a[0].activities.map{ |e| e['orgmodel'] if e['domain']==Riddl::Protocols::Utils::unescape(@r[-3])}.uniq.each do |e|
      next if e == nil
      XML::Smart.open(e) do |doc|
        doc.register_namespace 'o', 'http://cpee.org/ns/organisation/1.0'
        doc.find("/o:organisation/o:subjects/o:subject[@uid='#{@r[-2]}']/o:relation").each do |rel|
          @a[0].activities.each do |cb| 
            if (cb['role']=='*' || cb['role'].casecmp(rel.attributes['role']) == 0) && (cb['unit'] == '*' || cb['unit'].casecmp(rel.attributes['unit']) == 0) && (cb['user']=='*' || cb['user']==@r[-2]) 
              tasks["#{cb['id']}"] = {:uid => cb['user'], :label => cb['label'] }
            end
          end
        end  
      end  
    end
    tasks.each{|k,v| out.root.add("task", :id => k, :uid => v[:uid], :label => v[:label])}
    x = Riddl::Parameter::Complex.new("return","text/xml") do
      out.to_s
    end
    x
  end
end  #}}}  

class TaskTake < Riddl::Implementation #{{{
  def response
    index = @a[0].activities.index{ |c| c["id"] == @r.last }                                                 
    if index 
      @a[0].activities[index]["user"] = @r[-3]
      callback_id = @a[0].activities[index]['id']
      @a[0].activities.serialize
      @a[0].notify('user/take', :index => callback_id, :user => @r[-3])
      Riddl::Client.new(@a[0].activities[index]['url']).put [
        Riddl::Header.new('CPEE_UPDATE','true'),
        Riddl::Header.new('CPEE_UPDATE_STATUS','take')
      ]
    else
      @status = 404
    end
  end
end  #}}} 

class TaskGiveBack < Riddl::Implementation #{{{
  def response
    index = @a[0].activities.index{ |c| c["id"] == @r.last }
    if index && (@a[0].activities[index]['user'] == @r[-3])
      @a[0].activities[index]["user"] = '*'
      callback_id = @a[0].activities[index]['id']
      @a[0].activities.serialize
      @a[0].notify('user/giveback', :index => callback_id )
      Riddl::Client.new(@a[0].activities[index]['url']).put [
        Riddl::Header.new('CPEE_UPDATE','true'),
        Riddl::Header.new('CPEE_UPDATE_STATUS','giveback')
      ]
    else
      @status = 404
    end
  end
end  #}}} 

class TaskDetails < Riddl::Implementation #{{{
  def response
    index = @a[0].activities.index{ |c| c["id"] == @r.last } 
    if index 
      [Riddl::Parameter::Simple.new("callbackurl", @a[0].activities[index]['url']), Riddl::Parameter::Simple.new("formurl", @a[0].activities[index]['form']), Riddl::Parameter::Simple.new("parameters", @a[0].activities[index]['parameters'])]
    else
      @status = 404
    end
  end
end  #}}} 

class JSON_Task_Details < Riddl::Implementation #{{{
  def response
    index = @a[0].activities.index{ |c| c["id"] == @r.last } 
    if index 
      Riddl::Parameter::Complex.new "data","application/json", JSON.generate({'url' => @a[0].activities[index]['url'], 'form' => @a[0].activities[index]['form'], 'parameters' => @a[0].activities[index]['parameters'], 'label' => @a[0].activities[index]['label']})
    else
      @status = 404
    end
  end
end  #}}} 

class Activity < Array #{{{
  def initialize(domain)
    super()
    @domain = domain
  end

  def unserialize
    self.clear
    self.clear.replace JSON.parse!(File.read(File.dirname(__FILE__) + "/domains/#{@domain}/activities.sav")) rescue []
  end

  def  serialize
    Thread.new do 
      File.write File.dirname(__FILE__) + "/domains/#{@domain}/activities.sav", JSON.dump(self)
    end  
  end
end #}}}
class ControllerItem #{{{
  attr_reader :communication, :events, :notifications, :activities, :notifications_handler

  def initialize(domain,opts)
    @events = {}
    @votes = {}
    @opts = opts
    @communication = {}
    @domain = domain
    @activities = Activity.new(domain)
    @orgmodels = []
    @notifications = Riddl::Utils::Notifications::Producer::Backend.new(
      File.dirname(__FILE__) + "/topics.xml",
      File.dirname(__FILE__) + "/domains/#{domain}/notifications/"
    )
    @notifications_handler = NotificationsHandler.new(self)
    @notifications.subscriptions.keys.each do |key|
      @notifications_handler.key(key).create
    end
  end

  def add_orgmodel(name,content) #{{{
    FileUtils.mkdir_p(File.dirname(__FILE__) + "/domains/#{@domain}/orgmodels/")
    @orgmodels << name unless @orgmodels.include?(name)
    File.write(File.dirname(__FILE__) + "/domains/#{@domain}/orgmodels/" + name, content)
  end #}}}

  def notify(what,content={})# {{{
    item = @events[what]
    if item
      item.each do |ke,ur|
        Thread.new(ke,ur) do |key,url|
          notf = notify_build_message(key,what,content)
          if url.class == String
            client = Riddl::Client.new(url,'http://riddl.org/ns/common-patterns/notifications-consumer/1.0/consumer.xml')
            params = notf.map{|ke,va|Riddl::Parameter::Simple.new(ke,va)}
            params << Riddl::Header.new("WORKLIST_BASE","") # TODO the contents of @opts
            params << Riddl::Header.new("WORKLIST_DOMAIN",@domain)
            client.post params
          elsif url.class == Riddl::Utils::Notifications::Producer::WS
            e = XML::Smart::string("<event/>")
            notf.each do |k,v|
              e.root.add(k,v)
            end
            url.send(e.to_s) rescue nil
          end  
        end
      end
    end
  end # }}}

  def notify_build_message(key,what,content)# {{{
    res = []
    res << ['key'                             , key]
    res << ['topic'                           , ::File::dirname(what)]
    res << ['event'                           , ::File::basename(what)]
    res << ['notification'                    , JSON::generate(content)]
    res << ['fingerprint-with-consumer-secret', Digest::MD5.hexdigest(res.join(''))]
  end # }}}
end #}}}
class Controller < Hash #{{{
  def initialize(opts)
    super()
    @opts = opts
    Dir::glob(File.dirname(__FILE__) + '/domains/*').each do |f|
      domain = File.basename(f)
      self[domain] = ControllerItem.new(domain,@opts)
      self[domain].activities.unserialize
    end
  end

  def add_callback(domain,activity)
    self[domain] ||= ControllerItem.new(domain,@opts)
    self[domain].activities << activity
    self[domain].activities.serialize
  end
end #}}}

Riddl::Server.new(::File.dirname(__FILE__) + '/worklist.xml', :port => 9302 ) do 
  accessible_description true
  cross_site_xhr true

  controller = Controller.new(@riddl_opts)
  interface 'main' do
    run ActivityHappens,controller if post 'activityhappens'
    run Show_Domains,controller if get
    on resource do |r|
      domain = r[:h]['RIDDL_DECLARATION_PATH'].split('/')[1]
      domain = Riddl::Protocols::Utils::unescape(domain)

      run Show_Domain_Users,controller[domain] if get
      on resource do
        on resource 'tasks' do
          run Show_Tasks,controller[domain] if get
          on resource do |r|
            run JSON_Task_Details,controller[domain] if get 'json_details'
            run TaskDetails,controller[domain] if get
            run TaskTake,controller[domain] if put 'take'
            run TaskGiveBack,controller[domain] if put 'giveback'
            run TaskDel,controller[domain] if delete
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
    use Riddl::Utils::Notifications::Producer::implementation(controller[domain].notifications, controller[domain].notifications_handler)
  end

end.loop!
