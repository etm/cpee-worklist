module Worklist
  class Activities < Array
    def initialize(opts,domain)
      super()
      @opts = opts
      @domain = domain
    end

    def unserialize
      self.clear.replace JSON.parse!(File.read(File.join(@opts[:top],@domain,'activities.sav'))) # rescue []
    end

    def  serialize
      Thread.new do
        File.write File.join(@opts[:top],@domain,'activities.sav'), JSON.pretty_generate(self)
      end
    end
  end
end

