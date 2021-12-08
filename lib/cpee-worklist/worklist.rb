module CPEE
  module Message
    WHO = 'cpee-worklist'
    TYPE = 'domain'
  end
end

module Worklist
  SERVER = File.expand_path(File.join(__dir__,'worklist.xml'))

  def self::watch_services(watchdog_start_off,url,path,db)
    return if watchdog_start_off
     EM.defer do
       Dir[File.join(__dir__,'routing','*.rb')].each do |s|
         s = s.sub(/\.rb$/,'')
         pid = (File.read(s + '.pid').to_i rescue nil)
         if (pid.nil? || !(Process.kill(0, pid) rescue false)) && !File.exist?(s + '.lock')
           if url.nil?
             system "#{s}.rb -p \"#{path}\" -d #{db} restart 1>/dev/null 2>&1"
           else
             system "#{s}.rb -u \"#{url}\" -d #{db} restart 1>/dev/null 2>&1"
           end
           puts "➡ Service #{File.basename(s,'.rb')} started ..."
         end
       end
    end
  end
  def self::cleanup_services(watchdog_start_off)
    return if watchdog_start_off
    Dir[File.join(__dir__,'routing','*.rb')].each do |s|
      s = s.sub(/\.rb$/,'')
      pid = (File.read(s + '.pid').to_i rescue nil)
      if !pid.nil? || (Process.kill(0, pid) rescue false)
        system "#{s}.rb stop 1>/dev/null 2>&1"
        puts "➡ Service #{File.basename(s,'.rb')} stopped ..."
      end
    end
  end
end
