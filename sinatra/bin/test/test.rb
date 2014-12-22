require 'riddl/client'
 
client = Riddl::Client.new('http://raph.cs.univie.ac.at/g')  
status, result, headers = client.post [
  Riddl::Parameter::Simple.new("mail","sahann@chello.at"),
  Riddl::Parameter::Simple.new("text","bla"),
  Riddl::Parameter::Simple.new("ok","nok")
]
      
p status
