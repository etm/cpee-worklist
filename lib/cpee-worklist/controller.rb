# This file is part of CPEE-WORKLIST
#
# CPEE-WORKLIST is free software: you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published by the
# Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# CPEE-WORKLIST is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
# details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with CPEE-WORKLIST (file LICENSE in the main directory). If not, see
# <http://www.gnu.org/licenses/>.

require 'cpee/persistence'
CPEE::Persistence::obj = 'worklist'

module CPEE
  module Worklist

    class Controller
      attr_reader :communication, :events, :notifications, :activities, :callback_keys, :votes, :opts, :orgmodels

      def initialize(opts)
        CPEE::redis_connect(opts,"Main")
        @opts = opts

        @redis = opts[:redis]
        @votes = []

        @activities = Activities.new(opts)
        @activities.unserialize

        CPEE::Persistence::new_static_object(CPEE::Persistence::obj,opts)

        @orgmodels = []
        Dir::glob(File.join(@opts[:top],'orgmodels','*')).each do |g|
          add_orgmodel File.basename(g), File.read(g)
        end

        @callback_keys = {}
        @psredis = @opts[:redis_dyn].call "Callback Response"

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

      def id
        'worklist'
      end
      def uuid
        @id
      end
      def host
        @opts[:host]
      end
      def base_url
        File.join(@opts[:url],'/')
      end
      def instance_url
        File.join(@opts[:url].to_s,'/')
      end
      def instance_id
        @id
      end
      def base
        base_url
      end

      def info
        'worklist'
      end

      def add_orgmodel(name,content) #{{{
        FileUtils.mkdir_p(File.join(@opts[:top],'orgmodels'))
        @orgmodels << name unless @orgmodels.include?(name)
        File.write(File.join(@opts[:top],'orgmodels',name), content)
      end #}}}

      def notify(what,content={})
        CPEE::Message::send(:event,what,base,info,uuid,info,content,@redis)
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
          CPEE::Message::send(:vote,what,base,info,uuid,info,content,@redis)
        end

        if votes.length > 0
          @votes += votes
          psredis = @opts[:redis_dyn].call "Vote"
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
        CPEE::Message::send(:callback,'activity/content',base,info,uuid,info,content.merge(:key => key),@redis)
        @callback_keys[key] = hw
      end

      def cancel_callback(key)
        CPEE::Message::send(:'callback-end',key,base,info,uuid,info,{},@redis)
      end

      def add_activity(activity)
        @activities << activity
        @activities.serialize
      end

    end

  end
end
