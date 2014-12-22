#!/usr/bin/ruby
require 'json'
require 'pp'

DATA_DIR    = "data/"
LOG_DIR     = "data/logs/"
USER_DIR    = "data/user/"
BIN_DIR     = "bin/"
TEST_DIR    = "bin/test/"
PUBLIC_HTML = "public/"

$callbacks = []

File.open(DATA_DIR+"callbacks.sav", "r") do |f|
  $callbacks = JSON.parse!(f.read) rescue []
end

at_exit{
  File.open(DATA_DIR+"callbacks.sav", "w") do |f|
    JSON.dump($callbacks, f)
  end
}

require 'net/smtp'
require 'sinatra'
require 'sinatra/json'

eval File.read(BIN_DIR+'sendmail.rb')

set :port, 80
set :environment, :production
set :public_folder, PUBLIC_HTML 

get '/hi' do
  'Hello World'
end

get '/' do
  send_file File.join(settings.public_folder, 'index.html')
end

get '/test' do
  send_file TEST_DIR+'test.html'
end

name = ["Sahann", "Reiterer", "Moser", "Timotic", "Xu"]
mail = ["@gmail.com", "@gmx.at", "@hotmail.com", "@chello.at", "@web.de"]
garage = ["Wien", "Linz", "Klagenfurt", "Salzburg", "Bregenz"]

get '/a' do
  n = name[rand(0...(name.length))]
  v = rand(1000...10000000)
  m = n.downcase + mail[rand(0...(mail.length))]
  g = garage[rand(0...(garage.length))]+rand(-3..-1).to_s
  s = rand(1000...1000000)
  
  answer = {:name => n, 
            :versicherungsnummer => v, 
            :mail => m, 
            :garage => g,
            :schadenssumme => s}
  json answer  
end

get '/b/:name' do |n|
  return "gering" if n.length%2 != 1
  return "hoch"
end

get '/b' do
  return "gering" if params[:name].length%2 != 1
  return "hoch"
end

get '/c' do
  ((params[:schadenssumme].to_i)/2).to_s
end

post '/d' do 
  logger.info request.env["HTTP_CPEE_INSTANCE"]
  logger.info params[:garage]
  File.open(LOG_DIR+params[:garage].to_s+".log", "a") do |f|
    f.write Time.now.strftime("%Y-%m-%d %H:%M")
    f.write " : "
    f.write request.env["HTTP_CPEE_INSTANCE"].to_s
    f.write "\n"
  end
  200 
end

get '/e' do
  r = rand(0..2)
  case r
    when 0
      return "Dieser Kunde ist der Teufel. Ich kann nicht mehr. Hiermit kuendige ich."
    when 1
      return "Im letzten Jahr bereits ein Schaden vorgefallen."
    when 2
      return "Absoluter Tollpatsch, macht staendig alles kaputt. Keine weiteren Schaeden mehr bezahlen!"
  end
end

get '/f' do
  if rand(0..1) == 1
    "OK"
  else
    "NOK"
  end
end

post '/g' do
  case params[:mail].downcase 
    when /^sahann/
      sendmail("mhmnn9@gmail.com", params[:ok])
      return 200
    when /^timotic/
      sendmail("manuel.timotic@chello.at", params[:ok])
      return 200
    when /^moser|^reiterer|^diemichis/
      sendmail("diemichis@gmx.at", params[:ok])
      return 200
    when /^xu/
      sendmail("mhmnn9@gmail.com", params[:ok])
      return 200
    else
      return 403
  end
end

get '/worklist' do
  send_file 'worklist/worklist.html'
end

get '/callbacks' do
  eval File.read(BIN_DIR+"callbacks.rb")
end  

get '/callbackspoll' do
  eval File.read(BIN_DIR+"callbackspoll.rb")
end  

post '/callbacks' do
  eval File.read(BIN_DIR+"callbacks_post.rb")
end  

delete '/callbacks/:id' do |id|
  eval File.read(BIN_DIR+"callbacks_delete.rb")
end

get '/working' do
  index = $callbacks.index{ |c| c["id"] == params[:id] }
  $callbacks[index]["worker"] = params[:user]
end

get '/unworking' do
  index = $callbacks.index{ |c| c["id"] == params[:id] }
  $callbacks[index]["worker"] = ""
end
