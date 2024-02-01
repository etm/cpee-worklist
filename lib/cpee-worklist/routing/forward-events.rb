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
require 'cpee/redis'

Daemonite.new do |opts|
  opts[:runtime_opts] += [
    ["--url=URL", "-uURL", "Specify redis url", ->(p){ opts[:redis_url] = p }],
    ["--path=PATH", "-pPATH", "Specify redis path, e.g. /tmp/redis.sock", ->(p){ opts[:redis_path] = p }],
    ["--db=DB", "-dDB", "Specify redis db, e.g. 1", ->(p) { opts[:redis_db] = p.to_i }]
  ]

  on startup do
    opts[:redis_path] ||= '/tmp/redis.sock'
    opts[:redis_db] ||= 1

    CPEE::redis_connect opts, 'Server Routing Forward Events'
    opts[:pubsubredis] = opts[:redis_dyn].call 'Server Routing Forward Events Sub'
  end

  run do
    opts[:pubsubredis].psubscribe('event:*') do |on|
      on.pmessage do |pat, what, message|
        index = message.index(' ')
        mess = message[index+1..-1]
        instance = message[0...index]
        type, worker, event = what.split(':',3)
        topic = ::File::dirname(event)
        name = ::File::basename(event)
        long = File.join(topic,type,name)
        opts[:redis].smembers("worklist:#{instance}/handlers").each do |key|
          if opts[:redis].smembers("worklist:#{instance}/handlers/#{key}").include? long
            url = opts[:redis].get("worklist:#{instance}/handlers/#{key}/url")
            if url.nil? || url == ""
              opts[:redis].publish("forward:#{instance}/#{key}",mess)
            else
              p "#{type}/#{topic}/#{event}-#{url}"
              client = Riddl::Client.new(url)
              client.post [
                Riddl::Parameter::Simple::new('type',type),
                Riddl::Parameter::Simple::new('topic',topic),
                Riddl::Parameter::Simple::new('event',name),
                Riddl::Parameter::Complex::new('notification','application/json',mess)
              ]
            end
          end
        end
        unless opts[:redis].exists?("worklist:#{instance}/state")
          empt = opts[:redis].keys("worklist:#{instance}/*").to_a
          opts[:redis].multi do |multi|
            multi.del empt
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
