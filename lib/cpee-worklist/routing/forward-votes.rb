#!/usr/bin/ruby
#
# This file is part of cpee-worklist.
#
# cpee-worklist is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option) any
# later version.
#
# cpee-worklist is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# cpee-worklist (file COPYING in the main directory).  If not, see
# <http://www.gnu.org/licenses/>.

require 'redis'
require 'daemonite'
require 'riddl/client'
require 'json'
require 'cpee/message'
require 'cpee/redis'

def persist_handler(instance,key,mess,redis) #{{{
  redis.multi do |multi|
    multi.sadd("worklist:#{instance}/callbacks",key)
    multi.set("worklist:#{instance}/callback/#{key}/subscription",mess.dig('content','subscription'))
    multi.set("worklist:#{instance}/callback/#{key}/uuid",mess.dig('content','activity-uuid'))
    multi.set("worklist:#{instance}/callback/#{key}/label",mess.dig('content','label'))
    multi.set("worklist:#{instance}/callback/#{key}/position",mess.dig('content','activity'))
    multi.set("worklist:#{instance}/callback/#{key}/type",'vote')
  end
end #}}}

def send_response(instance,key,url,value,redis) #{{{
  CPEE::Message::send(
    :'vote-response',
    key,
    url,
    instance,
    {},
    {},
    value,
    redis
  )
end #}}}

Daemonite.new do |opts|
  opts[:runtime_opts] += [
    ["--url=URL", "-uURL", "Specify redis url", ->(p){ opts[:redis_url] = p }],
    ["--path=PATH", "-pPATH", "Specify redis path, e.g. /tmp/redis.sock", ->(p){ opts[:redis_path] = p }],
    ["--db=DB", "-dDB", "Specify redis db, e.g. 1", ->(p) { opts[:redis_db] = p.to_i }]
  ]

  on startup do
    opts[:redis_path] ||= '/tmp/redis.sock'
    opts[:redis_db] ||= 1

    CPEE::redis_connect opts, 'Server Routing Forward Votes'
    opts[:pubsubredis] = opts[:redis_dyn].call 'Server Routing Forward Votes Sub'
  end

  run do
    opts[:pubsubredis].psubscribe('vote:00:*') do |on|
      on.pmessage do |pat, what, message|
        index = message.index(' ')
        mess = message[index+1..-1]
        instance = message[0...index]
        type, worker, event = what.split(':',3)
        topic = ::File::dirname(event)
        name = ::File::basename(event)
        long = File.join(topic,type,name)

        opts[:redis].smembers("worklist:#{instance}/handlers").each do |subscription_key|
          if opts[:redis].smembers("worklist:#{instance}/handlers/#{subscription_key}").include? long
            m = JSON.parse(mess)
            callback_key = m.dig('content','key')
            url = opts[:redis].get("worklist:#{instance}/handlers/#{subscription_key}/url")

            if url.nil? || url == ""
              persist_handler instance, callback_key, m, opts[:redis]
              opts[:redis].publish("forward:#{instance}/#{subscription_key}",mess)
            else
              client = Riddl::Client.new(url)
              callback = File.join(m['instance-url'],'/callbacks/',subscription_key,'/')
              status, result, headers = (client.post [
                Riddl::Header.new("CPEE-WL-BASE",File.join(m['cpee'],'/')),
                Riddl::Header.new("CPEE-WL-DOMAIN",m['instance']),
                Riddl::Header.new("CPEE-WL-DOMAIN-URL",File.join(m['instance-url'],'/')),
                Riddl::Header.new("CPEE-WL-DOMAIN-UUID",m['instance-uuid']),
                Riddl::Header.new("CPEE-WL-CALLBACK",callback),
                Riddl::Header.new("CPEE-WL-CALLBACK-ID",subscription_key),
                Riddl::Parameter::Simple::new('type',type),
                Riddl::Parameter::Simple::new('topic',topic),
                Riddl::Parameter::Simple::new('vote',name),
                Riddl::Parameter::Simple::new('callback',callback),
                Riddl::Parameter::Complex::new('notification','application/json',mess)
              ] rescue [ 0, [], []])
              if status >= 200 && status < 300
                val = if result[0].class == Riddl::Parameter::Simple
                  result[0].value
                else
                  result[0].value.read
                end
                if (headers["CPEE_CALLBACK"] && headers["CPEE_CALLBACK"] == 'true') || val == 'callback'
                  persist_handler instance, callback_key, m, opts[:redis]
                else # they may send true or false
                  send_response instance, callback_key, m['cpee'], val, opts[:redis]
                end
              else
                send_response instance, callback_key, m['cpee'], true, opts[:redis]
              end
            end
          end
        end
      rescue => e
        puts e.message
        puts e.backtrace
        p '-----------------'
      end
    end
  end
end.go!
