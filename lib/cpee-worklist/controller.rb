require 'cpee/persistence'

module Worklist

  class Controller < Hash
    attr_reader :opts  # geht ohne net
    def initialize(opts)
      super()
      CPEE::redis_connect(opts,"Main")
      @opts = opts
      Dir::glob(opts[:domains]).each do |f|
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
  end

  class ControllerItem
    attr_reader :communication, :events, :notifications, :activities, :callback_keys, :votes, :opts, :orgmodels, :domain

    def initialize(domain,opts)
      @redis = opts[:redis]
      @votes = []

      @domain = domain

      @opts = opts

      @activities = Activities.new(opts,domain)
      @orgmodels = []

      @callback_keys = {}
      @psredis = @opts[:redis_dyn].call "Comain #{@id} Callback Response"

      Thread.new do
        @psredis.psubscribe('callback-response:*','callback-end:*') do |on|
          on.pmessage do |pat, what, message|
            if pat == 'callback-response:*' && @callback_keys.has_key?(what[18..-1])
              index = message.index(' ')
              mess = message[index+1..-1]
              instance = message[0...index]
              m = JSON.parse(mess)
              resp = []
              m['content']['values'].each do |e|
                if e[1][0] == 'simple'
                  resp << Riddl::Parameter::Simple.new(e[0],e[1][1])
                elsif e[1][0] == 'complex'
                  resp << Riddl::Parameter::Complex.new(e[0],e[1][1],File.open(e[1][2]))
                end
              end
              @callback_keys[what[18..-1]].send(:callback,resp,m['content']['headers'])
            end
            if pat == 'callback-end:*'
              @callback_keys.delete(what[13..-1])
            end
          end
        end
      end
    end

    attr_reader :id
    def uuid
      @domain
    end
    def host
      @opts[:host]
    end
    def base_url
      File.join(@opts[:url],'/')
    end
    def instance_url
      File.join(@opts[:url].to_s,@domain.to_s,'/')
    end
    def instance_id
      @domain
    end
    def base
      base_url
    end

    def info
      @domain
    end

    def add_orgmodel(name,content) #{{{
      FileUtils.mkdir_p(File.join(@opts[:top],@domain,'orgmodels'))
      @orgmodels << name unless @orgmodels.include?(name)
      File.write(File.join(@opts[:top],@domain,'orgmodels',name), content)
    end #}}}

    def notify(what,content={})
      CPEE::Message::send(:event,what,base,@domain,uuid,info,content,@redis)
    end

    def vote(what,content={})
      topic, name = what.split('/')
      handler = File.join(topic,'vote',name)
      votes = []
      CPEE::Persistence::extract_handler(id,@opts,handler).each do |client|
        voteid = Digest::MD5.hexdigest(Kernel::rand().to_s)
        content[:key] = voteid
        content[:subscription] = client
        votes << voteid
        CPEE::Message::send(:vote,what,base,@domain,uuid,info,content,@redis)
      end

      if votes.length > 0
        @votes += votes
        psredis = @opts[:redis_dyn].call "Domain #{@domain} Vote"
        collect = []
        psredis.subscribe(votes.map{|e| ['vote-response:' + e.to_s] }.flatten) do |on|
          on.message do |what, message|
            index = message.index(' ')
            mess = message[index+1..-1]
            m = JSON.parse(mess)
            collect << ((m['content'] == true || m['content'] == 'true') || false)
            @votes.delete m['name']
            cancel_callback m['name']
            if collect.length >= votes.length
              psredis.unsubscribe
            end
          end
        end
        !collect.include?(false)
      else
        true
      end
    end

    def callback(hw,key,content)
      CPEE::Message::send(:callback,'activity/content',base,@domain,uuid,info,content.merge(:key => key),@redis)
      @callback_keys[key] = hw
    end

    def cancel_callback(key)
      CPEE::Message::send(:'callback-end',key,base,@domain,uuid,info,{},@redis)
    end
  end

end
