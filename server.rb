#!/usr/bin/ruby
require 'pp'
require 'fileutils'
require 'rubygems'
require 'riddl/server'
require 'riddl/client'
require 'riddl/utils/notifications_producer'
require 'riddl/utils/fileserve'

port = File.read(File.dirname(__FILE__)+'/port')
lh =   File.read(File.dirname(__FILE__)+'/localhost')

class Continue #{{{
  def initialize
    @q = Queue.new
    @m = Mutex.new
  end
  def waiting?
    @m.synchronize do
      !@q.empty?
    end
  end
  def continue(*args)
    @q.push(args.length <= 1 ? args[0] : args)
  end
  def clear
   @q.clear
  end
  def wait
    @q.deq
  end
end #}}}

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
      @data.callbacks[callback].callback([Riddl::Parameter::Simple.new('wsvote',result)])
      @data.callbacks.delete(callback)
    rescue => e
      puts e.message
      puts e.backtrace
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
      begin
        xml =  content[0].value.read
        schema = XML::Smart.open(@a[0].opts['ORG_SCHEMA'])
        org_xml = XML::Smart.string(xml)
        raise 'a fucked up xml (wink wink)' unless org_xml.validate_against(schema)
        org_xml.register_namespace 'o', 'http://cpee.org/ns/organisation/1.0'
      rescue => e
        puts e.message
        puts e.backtrace
        @a[0][domain].notify('task/invalid', :callback_id => activity['id'], :reason => 'orgmodel invalid') if @a[0].keys.include? domain
        @status = 404 
        return 
      end
      attributes = ""
      if activity['role'] != '*'
        attributes += "@role='#{activity['role']}'"
        attributes += " and " if activity['unit'] != '*'
      end
      attributes += "@unit='#{activity['unit']}'" if activity['unit'] != '*'
      user = org_xml.find("/o:organisation/o:subjects/o:subject[o:relation[#{attributes}]]").map{ |e| e.attributes['uid'] }
      if user.empty?
        @a[0][domain].notify('task/invalid', :callback_id => activity['id'], :reason => 'no users found for this combination of unit/role') if @a[0].keys.include? domain
        @status = 404 
        return
      end
      @a[0].add_activity domain, activity
      @a[0][domain].add_orgmodel Riddl::Protocols::Utils::escape(activity['orgmodel']), xml
      Thread.new do
        results = @a[0][domain].vote('task/add', :user => user , :cpee_callback => @h['CPEE_CALLBACK'], :cpee_instance => @h['CPEE_INSTANCE'], :cpee_base => @h['CPEE_BASE'], :cpee_label => @h['CPEE_LABEL'], :cpee_activity => @h['CPEE_ACTIVITY'])
        if (results.length == 1) && (user.include? results[0])
          activity["user"] = results[0]
          @a[0][domain].notify('task/add', :user => user , :cpee_callback => @h['CPEE_CALLBACK'], :cpee_instance => @h['CPEE_INSTANCE'], :cpee_base => @h['CPEE_BASE'], :cpee_label => @h['CPEE_LABEL'], :cpee_activity => @h['CPEE_ACTIVITY'])
          @a[0][domain].notify('user/take', :index => activity['id'], :user => results[0])
        else
          @a[0][domain].notify('task/add', :user => user , :cpee_callback => @h['CPEE_CALLBACK'], :cpee_instance => @h['CPEE_INSTANCE'], :cpee_base => @h['CPEE_BASE'], :cpee_label => @h['CPEE_LABEL'], :cpee_activity => @h['CPEE_ACTIVITY']) if @a[0].keys.include? domain
        end
      end
      @headers << Riddl::Header.new('CPEE_CALLBACK','true')
    else
      @status = 404
    end
  end
end #}}} 

class TaskDel < Riddl::Implementation #{{{
  def response
    index = @a[0].activities.index{ |e| e["id"] == @r.last }
    if index 
      activity = @a[0].activities.delete_at(index)
      @a[0].activities.serialize
      if @r.length == 3
        @a[0].notify('task/delete', :index => activity['callback_id'] )
        Riddl::Client.new(activity['url']).put
      else
        @a[0].notify('user/finish', :index => activity['callback_id'], :user => activity['user'])
      end
    else 
      @status = 404
    end
  end
end  #}}} 

class Show_Domains < Riddl::Implementation #{{{
  def response
    out = XML::Smart.string('<domains/>')
    @a[0].keys.each { |x| out.root.add('domain', :name=> x)}
    Riddl::Parameter::Complex.new("domains","text/xml") do
      out.to_s
    end
  end
end  #}}}  

class Show_Domain_Users < Riddl::Implementation #{{{
  def response
    out = XML::Smart.string('<users/>')
    @a[0].orgmodels.each do |fname|
      doc = XML::Smart.open(File.dirname(__FILE__) + "/domains/#{Riddl::Protocols::Utils::unescape(@r.last)}/orgmodels/#{fname}")
      doc.register_namespace 'o', 'http://cpee.org/ns/organisation/1.0'
      doc.find('/o:organisation/o:subjects/o:subject').each{ |e| out.root.add('user', :name => e.attributes['id'], :uid => e.attributes['uid'] ) }
    end  
    Riddl::Parameter::Complex.new("users","text/xml", out.to_s) 
  end
end  #}}} 

class Show_Tasks < Riddl:: Implementation #{{{
  def response
    out = XML::Smart.string('<tasks/>')
    tasks = {}
    @a[0].orgmodels.each do |e|
      XML::Smart.open("domains/#{@a[0].domain}/orgmodels/#{e}") do |doc|
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
    pp @a[0].activities
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
    pp @a[0].activities
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
      Riddl::Parameter::Complex.new "data","application/json", JSON.generate({'url' => @a[0].activities[index]['url'], 'form' => @a[0].activities[index]['form'], 'parameters' => @a[0].activities[index]['parameters'], 'label' => @a[0].activities[index]['label']})
    else
      @status = 404
    end
  end
end  #}}} 

class ExCallback < Riddl::Implementation #{{{
  def response
    controller = @a[0]
    id = @r[0].to_i
    callback = @r[2]
    controller[id].mutex.synchronize do
      if controller[id].callbacks.has_key?(callback)
        controller[id].callbacks[callback].callback(@p,@h)
      end
    end  
  end
end #}}}

class Callbacks < Riddl::Implementation #{{{
  def response
    controller = @a[0]
    opts = @a[0].opts
    id = @r[0].to_i
    unless controller[id]
      @status = 400
      return
    end
    Riddl::Parameter::Complex.new("info","text/xml") do
      cb = XML::Smart::string("<callbacks details='#{opts[:mode]}'/>")
      if opts[:mode] == :debug
        controller[id].callbacks.each do |k,v|
          cb.root.add("callback",{"id" => k},"[#{v.protocol.to_s}] #{v.info}")
        end  
      end
      cb.to_s
    end  
  end
end #}}}

class GetOrgModels < Riddl::Implementation #{{{
  def response
    out = XML::Smart.string('<orgmodels/>')
    @a[0].orgmodels.each{|e|pp e; out.root.add("orgmodel", e)}
    Riddl::Parameter::Complex.new "return","text/xml", out.to_s 
  end
end #}}}

class Activities < Array #{{{
  def initialize(domain)
    super()
    @domain = domain
  end

  def unserialize
    self.clear.replace JSON.parse!(File.read(File.dirname(__FILE__) + "/domains/#{@domain}/activities.sav")) rescue []
  end

  def  serialize
    Thread.new do 
      File.write File.dirname(__FILE__) + "/domains/#{@domain}/activities.sav", JSON.pretty_generate(self)
    end  
  end
end #}}}

class ControllerItem #{{{
  attr_reader :communication, :events, :notifications, :activities, :notifications_handler, :votes, :votes_results, :mutex, :callbacks, :opts, :orgmodels, :domain

  def initialize(domain,opts)
    @events = {}
    @votes = {}
    @votes_results = {}
    @mutex = Mutex.new
    @opts = opts
    @communication = {}
    @callbacks = {}
    @domain = domain
    @activities = Activities.new(domain)
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

  class Callback #{{{
    def initialize(info,handler,method,event,key,protocol,*data)
      @info = info
      @event = event
      @key = key
      @data = data
      @handler = handler
      @protocol = protocol
      @method = method.class == Symbol ? method : :callback
    end

    attr_reader :info, :protocol, :method

    def delete_if!(event,key)
      if @key == key && @event == event
        puts "====="
        puts *@data
        puts *@data.length
        puts "===="
        puts @method
        puts "===="
        #TODO JUERGEN SOLLTE KONTROLLIEREN
        @handler.send @method, :DELETE,nil, *@data 
      end
      nil
    end

    def callback(result=nil,options=[])
      @handler.send @method, result, options, *@data
    end
  end #}}}

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
          notf = build_message(key,what,content)
          if url.class == String
            client = Riddl::Client.new(url,'http://riddl.org/ns/common-patterns/notifications-consumer/1.0/consumer.xml')
            params = notf.map{|ke,va|Riddl::Parameter::Simple.new(ke,va)}
            params << Riddl::Header.new("WORKLIST_BASE",@opts[:url]) 
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

  def vote(what,content={})# {{{
    voteid = Digest::MD5.hexdigest(Kernel::rand().to_s)
    item = @votes[what]
    if item && item.length > 0
      continue = Continue.new
      @votes_results[voteid] = []
      inum = 0
      item.each do |key,url|
        if url.class == String
          inum += 1
        elsif url.class == Riddl::Utils::Notifications::Producer::WS
          inum += 1 unless url.closed?
        end  
      end
      item.each do |key,url|
        Thread.new(key,url,content.dup) do |k,u,c|
          callback = Digest::MD5.hexdigest(Kernel::rand().to_s)
          notf = build_message(k,what,c,'vote',callback)
          if u.class == String
            client = Riddl::Client.new(u,'http://riddl.org/ns/common-patterns/notifications-consumer/1.0/consumer.xml',:xmpp => @opts[:xmpp])
            params = notf.map{|ke,va|Riddl::Parameter::Simple.new(ke,va)}
            params << Riddl::Header.new("WORKLIST_BASE",@opts[:url])
            params << Riddl::Header.new("WORKLIST_DOMAIN",@domain)
            @mutex.synchronize do
              status, result, headers = client.post params
              if headers["WORKLIST_CALLBACK"] && headers["WORKLIST_CALLBACK"] == 'true'
                @callbacks[callback] = Callback.new("vote #{notf.find{|a,b| a == 'notification'}[1]}", self, :vote_callback, what, k, :http, continue, voteid, callback, inum)
              else
                vote_callback(result,nil,continue,voteid,callback,inum)
              end
            end  
          elsif u.class == Riddl::Utils::Notifications::Producer::WS
            @callbacks[callback] = Callback.new("vote #{notf.find{|a,b| a == 'notification'}[1]}", self, :vote_callback, what, k, :ws, continue, voteid, callback, inum)
            e = XML::Smart::string("<vote/>")
            notf.each do |ke,va|
              e.root.add(ke,va)
            end
            u.send(e.to_s) rescue nil
          end
        end

      end
      continue.wait

      @votes_results.delete(voteid).compact.uniq
    else  
      []
    end
  end # }}}

  def vote_callback(result,options,continue,voteid,callback,num)# {{{
    @callbacks.delete(callback)
    if result == :DELETE
      @votes_results[voteid] << nil
    else
      @votes_results[voteid] << ((result && result[0]) ? result[0].value : nil)
    end  
    if (num == @votes_results[voteid].length)
      continue.continue
    end  
  end # }}}
  
  def build_message(key,what,content,type='event',callback=nil)# {{{
    res = []
    res << ['key'                             , key]
    res << ['topic'                           , ::File::dirname(what)]
    res << [type                              , ::File::basename(what)]
    res << ['notification'                    , JSON::generate(content)]
    res << ['callback'                        , callback] unless callback.nil?
    res << ['fingerprint-with-consumer-secret', Digest::MD5.hexdigest(res.join(''))]
  end # }}}

end #}}}

class Controller < Hash #{{{
  attr_reader :opts  # geht ohne net
  def initialize(opts)
    super()
    @opts = opts
    Dir::glob(File.dirname(__FILE__) + '/domains/*').each do |f|
      domain = File.basename(f)
      self[domain] = ControllerItem.new(domain,@opts)
      self[domain].activities.unserialize
      Dir::glob("#{f}/orgmodels/*").each do |g|
        self[domain].add_orgmodel File.basename(g), File.read(g)
      end
    end
  end

  def add_activity(domain,activity)
    self[domain] ||= ControllerItem.new(domain,@opts)
    self[domain].activities << activity
    self[domain].activities.serialize
  end
end #}}}
  
Riddl::Server.new(::File.dirname(__FILE__) + '/worklist.xml', :port => port, :host => lh) do 
  accessible_description true
  cross_site_xhr true

  @riddl_opts['ORG_SCHEMA'] =  ::File.dirname(__FILE__) + '/organisation.rng'

  controller = Controller.new(@riddl_opts)
  interface 'main' do
    run ActivityHappens,controller if post 'activityhappens'
    run Show_Domains,controller if get
    on resource do |r|
      domain = r[:h]['RIDDL_DECLARATION_PATH'].split('/')[1]
      domain = Riddl::Protocols::Utils::unescape(domain)
      if controller.keys.include? domain
        run Show_Domain_Users,controller[domain] if get
        on resource 'callbacks' do
          run Callbacks,controller[domain] if get
          on resource do
            run ExCallback,controller[domain] if put
          end  
        end
        on resource 'orgmodels' do
          run GetOrgModels, controller[domain] if get
        end
        on resource 'tasks' do
          on resource do
            run TaskDel,controller[domain] if delete
          end
        end
        on resource do
          on resource 'tasks' do
            run Show_Tasks,controller[domain] if get
            on resource do |r|
              run TaskDetails,controller[domain] if get 
              run TaskTake,controller[domain] if put 'take'
              run TaskGiveBack,controller[domain] if put 'giveback'
              run TaskDel,controller[domain] if delete
            end
          end
        end
      end
    end
  end

  interface 'events' do |r|
    domain = r[:h]['RIDDL_DECLARATION_PATH'].split('/')[1]
    domain = Riddl::Protocols::Utils::unescape(domain)
    use Riddl::Utils::Notifications::Producer::implementation(controller[domain].notifications, controller[domain].notifications_handler) if controller.keys.include? domain
  end

end.loop!
