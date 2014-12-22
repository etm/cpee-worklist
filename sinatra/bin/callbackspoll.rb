def changedState(state, role)
  if role == "admin" 
    0.upto 60 do |i|
      if $callbacks.to_s != state 
        return json $callbacks
      end
      sleep 0.5
    end
    400 
  else
    newstate = []
    0.upto 60 do |i|
      newstate = $callbacks.select { |c| c["role"] == role }
      if newstate.to_s != state
        return json newstate
      end
      sleep 0.5
    end
    400
  end 
end

if File.open(USER_DIR+"worker.txt").lines.any?{|line| line.include? params[:user] }
  state = Array.new( $callbacks.select { |c| c["role"] == "worker" } )
  changedState( state.to_s , "worker" )
elsif File.open(USER_DIR+"clerk.txt").lines.any?{|line| line.include? params[:user] }
  state = Array.new ( $callbacks.select { |c| c["role"] == "clerk" } )
  changedState( state.to_s, "clerk" )
elsif File.open(USER_DIR+"admin.txt").lines.any?{|line| line.include? params[:user] }
  state = Array.new( $callbacks ) 
  changedState( state.to_s, "admin")
else
  return 401
end
