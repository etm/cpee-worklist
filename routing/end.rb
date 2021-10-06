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
require_relative '../../lib/cpee/redis'

Daemonite.new do |opts|
  opts[:runtime_opts] += [
    ["--url=URL", "-uURL", "Specify redis url", ->(p){ opts[:redis_url] = p }],
    ["--path=PATH", "-pPATH", "Specify redis path, e.g. /tmp/redis.sock", ->(p){ opts[:redis_path] = p }],
    ["--db=DB", "-dDB", "Specify redis db, e.g. 1", ->(p) { opts[:redis_db] = p.to_i }]
  ]

  on startup do
    opts[:redis_path] ||= '/tmp/redis.sock'
    opts[:redis_db] ||= 1

    CPEE::redis_connect opts, 'Server Routing End'
    opts[:pubsubredis] = opts[:redis_dyn].call 'Server Routing End Sub'
  end

  run do
    opts[:pubsubredis].psubscribe('callback-end:*') do |on|
      on.pmessage do |pat, what, message|
        _, key = what.split(':')
        index = message.index(' ')
        domain = message[0...index]
        opts[:redis].multi do |multi|
          multi.srem("domain:#{domain}/callbacks",key)
          multi.del("domain:#{domain}/callback/#{key}/uuid")
          multi.del("domain:#{domain}/callback/#{key}/label")
          multi.del("domain:#{domain}/callback/#{key}/position")
          multi.del("domain:#{domain}/callback/#{key}/type")
          multi.del("domain:#{domain}/callback/#{key}/subscription")
        end
      rescue => e
        puts e.message
        puts e.backtrace
      end
    end
  end
end.go!
