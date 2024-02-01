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

require 'json'
require 'redis'
require 'daemonite'
require 'cpee/value_helper'
require 'cpee/redis'

EVENTS = %w{
  event:state/change
  event:handler/change
}

Daemonite.new do |opts|
  opts[:runtime_opts] += [
    ["--url=URL", "-uURL", "Specify redis url", ->(p){ opts[:redis_url] = p }],
    ["--path=PATH", "-pPATH", "Specify redis path, e.g. /tmp/redis.sock", ->(p){ opts[:redis_path] = p }],
    ["--db=DB", "-dDB", "Specify redis db, e.g. 1", ->(p) { opts[:redis_db] = p.to_i }]
  ]

  on startup do
    opts[:redis_path] ||= '/tmp/redis.sock'
    opts[:redis_db] ||= 1

    CPEE::redis_connect opts, 'Server Routing Persist'
    opts[:pubsubredis] = opts[:redis_dyn].call 'Server Routing Persist Sub'
  end

  run do
    opts[:pubsubredis].subscribe(EVENTS) do |on|
      on.message do |what, message|
        mess = JSON.parse(message[message.index(' ')+1..-1])
        case what
          when 'event:state/change'
            opts[:redis].multi do |multi|
              unless mess.dig('content','state') == 'purged'
                multi.set("worklist:#{instance}/state",mess.dig('content','state'))
                multi.set("worklist:#{instance}/state/@changed",mess.dig('timestamp'))
              end
            end
          when 'event:handler/change'
            opts[:redis].multi do |multi|
              mess.dig('content','changed').each do |c|
                multi.sadd("worklist:handlers",mess.dig('content','key'))
                multi.sadd("worklist:handlers/#{mess.dig('content','key')}",c)
                multi.set("worklist:#handlers/#{mess.dig('content','key')}/url",mess.dig('content','url'))
                multi.sadd("worklist:handlers/#{c}",mess.dig('content','key'))
              end
              mess.dig('content','deleted').to_a.each do |c|
                multi.srem("worklist:handlers/#{mess.dig('content','key')}",c)
                multi.srem("worklist:handlers/#{c}",mess.dig('content','key'))
              end
            end
            if opts[:redis].scard("worklist:handlers/#{mess.dig('content','key')}") < 1
              opts[:redis].multi do |multi|
                multi.del("worklist:handlers/#{mess.dig('content','key')}/url")
                multi.srem("worklist:handlers",mess.dig('content','key'))
              end
            end
        end
      rescue => e
        puts e.message
        puts e.backtrace
      end
    end
  end
end.go!
