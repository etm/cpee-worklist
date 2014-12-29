require 'riddl/client'
 
client = Riddl::Client.new('http://cpee.org:9299/callbacks')  
client.post [
  Riddl::Parameter::Simple.new("form","nichttoll"),
  Riddl::Parameter::Simple.new("role","Super-Sajyan"),
]
      
