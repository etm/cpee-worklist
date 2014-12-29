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
