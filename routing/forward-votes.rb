#!/usr/bin/ruby
#
# This file is part of CPEE.
#
# CPEE is free software: you can redistribute it and/or modify it under the terms
# of the GNU General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# CPEE is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# CPEE (file COPYING in the main directory).  If not, see
# <http://www.gnu.org/licenses/>.

require 'redis'
require 'daemonite'
require 'riddl/client'
require 'json'
require_relative 'cpee/message'
require_relative 'cpee/redis'

def persist_handler(domain,key,mess,redis) #{{{
  redis.multi do |multi|
    multi.sadd("domain:#{domain}/callbacks",key)
    multi.set("domain:#{domain}/callback/#{key}/subscription",mess.dig('content','subscription'))
    multi.set("domain:#{domain}/callback/#{key}/uuid",mess.dig('content','activity-uuid'))
    multi.set("domain:#{domain}/callback/#{key}/label",mess.dig('content','label'))
    multi.set("domain:#{domain}/callback/#{key}/position",mess.dig('content','activity'))
    multi.set("domain:#{domain}/callback/#{key}/type",'vote')
  end
end #}}}

def send_response(domain,key,url,value,redis) #{{{
  CPEE::Message::send(
    :'vote-response',
    key,
    url,
    domain,
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
    opts[:pubsubredis].psubscribe('vote:*') do |on|
      on.pmessage do |pat, what, message|
        index = message.index(' ')
        mess = message[index+1..-1]

        domain = message[0...index]
        type = pat[0..-3]
        event = what[(type.length+1)..-1]
        topic = ::File::dirname(event)
        name = ::File::basename(event)
        long = File.join(topic,type,name)

        opts[:redis].smembers("domain:#{domain}/handlers").each do |subscription_key|
          if opts[:redis].smembers("domain:#{domain}/handlers/#{subscription_key}").include? long
            m = JSON.parse(mess)
            callback_key = m.dig('content','key')
            url = opts[:redis].get("domain:#{domain}/handlers/#{subscription_key}/url")

            if url.nil? || url == ""
              persist_handler domain, callback_key, m, opts[:redis]
              opts[:redis].publish("forward:#{domain}/#{subscription_key}",mess)
            else
              client = Riddl::Client.new(url)
              callback = File.join(m['domain-url'],'/callbacks/',subscription_key,'/')
              status, result, headers = (client.post [
                Riddl::Header.new("CPEE-WORKLIST-BASE",File.join(m['cpee'],'/')),
                Riddl::Header.new("CPEE-WORKLIST-DOMAIN",m['domain']),
                Riddl::Header.new("CPEE-WORKLIST-DOMAIN-URL",File.join(m['domain-url'],'/')),
                Riddl::Header.new("CPEE-WORKLIST-DOMAIN-UUID",m['domain-uuid']),
                Riddl::Header.new("CPEE-WORKLIST-CALLBACK",callback),
                Riddl::Header.new("CPEE-WORKLIST-CALLBACK-ID",subscription_key),
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
                if (headers["CPEE_WORKLIST_CALLBACK"] && headers["CPEE_WORKLIST_CALLBACK"] == 'true') || val == 'callback'
                  persist_handler domain, callback_key, m, opts[:redis]
                else # they may send true or false
                  send_response domain, callback_key, m['cpee'], val, opts[:redis]
                end
              else
                send_response domain, callback_key, m['cpee'], true, opts[:redis]
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
