if File.open(USER_DIR+"worker.txt").lines.any?{|line| line.include? params[:user] }
  json $callbacks.select { |c| c["role"] == "worker"}
elsif File.open(USER_DIR+"clerk.txt").lines.any?{|line| line.include? params[:user] }
  json $callbacks.select { |c| c["role"] == "clerk" }
elsif File.open(USER_DIR+"admin.txt").lines.any?{|line| line.include? params[:user] }
  json $callbacks
else
  return 401
end
