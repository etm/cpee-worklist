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
    @data.communication[@key] = socket
    @data.events.each do |a|
      if a[1].has_key?(@key)
        a[1][@key] = socket
      end  
    end
    # eventuell notify dass handler change
  end
  def ws_close
    delete
    # eventuell notify dass handler change
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
   # @data.notify('properties/handlers/change', :instance => @data.instance)
  end
  def update
    if @data.notifications.subscriptions.include?(@key)
      url = @data.communication[@key]
      evs = []
      @data.events.each { |e,v| evs << e }
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
        end
      end
    end  
   # @data.notify('properties/handlers/change', :instance => @data.instance)
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

class Callbacks < Riddl::Implementation #{{{
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
      @a[0].add_callback domain, activity
      @a[0][domain].add_orgmodel Riddl::Protocols::Utils::escape(activity['orgmodel']), content[0].value.read
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
      @a[0].callbacks.serialize
      @a[0].notify('user/finish', :index => index )
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
    @a[0].callbacks.each{ |e| fname = e['orgmodel'] if e['domain'] == Riddl::Protocols::Utils::unescape(@r.last)}
    doc = XML::Smart.open(File.dirname(__FILE__) + "/domains/orgmodels/#{Riddl::Protocols::Utils::escape(fname)}")
    doc.register_namespace 'o', 'http://cpee.org/ns/organisation/1.0'
    doc.find('/o:organisation/o:subjects/o:subject').each{ |e| out.root.add('user', :name => e.attributes['id'], :uid => e.attributes['uid'] ) }
    Riddl::Parameter::Complex.new("return","text/xml", out.to_s) 
  end
end  #}}} 

class Show_Tasks < Riddl:: Implementation #{{{
  def response
    out = XML::Smart.string('<tasks/>')
    tasks = {}
    get_rel(@a[0].callbacks.map{ |e| e['orgmodel'] if e['domain']==Riddl::Protocols::Utils::unescape(@r[-3])}.uniq).each do |rel| 
      @a[0].callbacks.each do |cb| 
        if (cb['role']=='*' || cb['role'].casecmp(rel.attributes['role']) == 0) && (cb['unit'] == '*' || cb['unit'].casecmp(rel.attributes['unit']) == 0) && (cb['user']=='*' || cb['user']==@r[-2]) 
          tasks["#{cb['id']}"] = {:uid => cb['user'], :label => cb['label'] }
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

class Take_Task < Riddl::Implementation #{{{
  def response
    index = @a[0].callbacks.index{ |c| c["id"] == @r.last }                                                 
    if index 
      @a[0].callbacks[index]["user"] = @r[-3]
      @a[0].callbacks.serialize
      @a[0].notify('user/take', :index => index, :user => @r[-3])
    else
      @status = 404
    end
  end
end  #}}} 

class Return_Task < Riddl::Implementation #{{{
  def response
    index = @a[0].callbacks.index{ |c| c["id"] == @r.last }
    if index && (@a[0].callbacks[index]['user'] == @r[-3])
      @a[0].callbacks[index]["user"] = '*'
      @a[0].callbacks.serialize
      @a[0].notify('user/giveback', :index => index )
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

class CallbackItem < Array #{{{
  def initialize(domain)
    super()
    @domain = domain
  end

  def unserialize
    self.clear
    self.clear.replace JSON.parse!(File.read(File.dirname(__FILE__) + "/domains/#{@domain}/callbacks.sav")) rescue []
  end

  def  serialize
    Thread.new do 
      File.write File.dirname(__FILE__) + "/domains/#{@domain}/callbacks.sav", JSON.dump(self)
    end  
  end
end #}}}
class ControllerItem #{{{
  attr_accessor :callbacks, :notifications
  attr_reader :communication, :events

  def initialize(domain,opts)
    @events = {}
    @opts = opts
    @communication = {}
    @domain = domain
    @callbacks = CallbackItem.new(domain)
    @orgmodels = []
    @notifications = nil
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
            p @opts
            params << Riddl::Header.new("WORKLIST_BASE","") # TODO
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
      self[domain].callbacks.unserialize
      self[domain].notifications = Riddl::Utils::Notifications::Producer::Backend.new(
        File.dirname(__FILE__) + "/topics.xml",
        File.dirname(__FILE__) + "/domains/#{domain}/notifications/"
      )
    end
  end

  def add_callback(domain,activity)
    self[domain] ||= ControllerItem.new(domain,@opts)
    self[domain].callbacks << activity
    self[domain].callbacks.serialize
    self[domain].notifications ||= Riddl::Utils::Notifications::Producer::Backend.new(
      File.dirname(__FILE__) + "/domains/#{domain}/notifications/"
    )
  end
end #}}}

Riddl::Server.new(::File.dirname(__FILE__) + '/worklist.xml', :port => 9302 ) do 
  accessible_description true
  cross_site_xhr true

  controller = Controller.new(@riddl_opts)
  interface 'main' do
    run Callbacks,controller if post 'activity'
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
    use Riddl::Utils::Notifications::Producer::implementation(controller[domain].notifications, NotificationsHandler.new(controller[domain]))
  end

end.loop!
