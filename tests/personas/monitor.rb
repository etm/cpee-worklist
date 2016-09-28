#!/usr/bin/ruby
require 'riddl/client'
require 'pp'
require 'xml/smart'
require 'json'
require 'yaml'
require 'uri'

def get_rule(notification,cat_event, rules)

  rules.each{ |r|
    if (/^#{r['trigger']['label']} \(\d*\)/ =~ notification['cpee_label'] || r['trigger']['label'].nil? || r['trigger']['label'].empty? ) \
      && (notification['orgmodel'] == r['trigger']['target'] || r['trigger']['target'].nil? || r['trigger']['label'].empty? ) \
      && cat_event ==  r['trigger']['event'] \
      && r['active'] == true then

      pp 'yes'
      return r
    else
      pp 'no'
      return nil
    end
  }
end

#ON Event
def on_task_add(notification,rule)
  do_task_take(notification,rule['action']['user'])
end

def on_user_take(notification,rule)
  case rule['action']['event']
  when 'user/giveback'
    do_task_giveback(notification)
  when 'user/finish'
    do_task_finish(notification)
  end

end
def on_user_giveback(notification,rule)
  do_task_take(notification,rule['action']['user'])
end

#DO Action
def do_task_giveback(notification)
  put_to_wl("/#{notification['domain']}/#{notification['user']}/tasks/#{notification['callback_id']}",[Riddl::Parameter::Simple.new("operation","giveback"),])
end

def do_task_take(notification,user)
  put_to_wl("/#{notification['domain']}/#{user}/tasks/#{notification['callback_id']}",[Riddl::Parameter::Simple.new("operation","take"),])
end
def do_task_finish(notification)
  pp notification
end

def put_to_wl(resource_url,parameters)
  resource_url = URI.escape(resource_url)
  srv = Riddl::Client.new('http://coms.wst.univie.ac.at:9300')
  res = srv.resource(resource_url)
  status, response = res.put parameters

  pp response
end

def main()
  domain   = "Virtual%20Business%201"

  path     = File.dirname(__FILE__)
  rules    = Array.new

  #load all the YAMLS in pat
  Dir.glob(path + '/rules/*.yml') do |yml_file|
    rules << YAML.load_file(yml_file)
  end

  srv = Riddl::Client.new('http://coms.wst.univie.ac.at:9300')
  res = srv.resource("/Virtual%20Business%201/notifications/subscriptions/")
  status, response = res.post [
    Riddl::Parameter::Simple.new("url","http://coms.wst.univie.ac.at"),
    Riddl::Parameter::Simple.new("topic","user"),
    Riddl::Parameter::Simple.new("events","take,giveback,finish"),
    Riddl::Parameter::Simple.new("topic","task"),
    Riddl::Parameter::Simple.new("events","add"),


  ]

    key = response.first.value
    res = srv.resource("/#{domain}/notifications/subscriptions/#{key}/ws/")

    res.ws do |conn|

      conn.stream do |msg|
        puts msg
        puts '--------------'
        topic, event, notification, cat_event = nil
        XML::Smart.string(msg.data) do |doc|
          topic        = doc.find('string(/event/topic)')
          event        = doc.find('string(/event/event)')
          notification = JSON.parse(doc.find("string(/event/notification)"))

          cat_event    = topic.to_s+'/'+event.to_s

          #select rule


        end
        rule = get_rule(notification, cat_event, rules)
        unless rule.nil? then
          case cat_event
          when 'task/add'
            on_task_add(notification,rule)
          when 'user/take'
            on_user_take(notification,rule)
          when 'user/giveback'
            on_user_giveback(notification,rule)
          end
        end
      end

      conn.errback do |e|
        puts "Got error: #{e}"
      end

    end
end
main()
