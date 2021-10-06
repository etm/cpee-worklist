module Worklist
  class Activities < Array
    def initialize(domain)
      super()
      @domain = domain
    end

    def unserialize
      self.clear.replace JSON.parse!(File.read(File.dirname(__FILE__) + "/domains/#{@domain}/activities.sav")) rescue []
    end

    def  serialize
      Thread.new do
        File.write File.dirname(__FILE__) + "/domains/#{@domain}/activities.sav", JSON.pretty_generate(self)
      end
    end
  end
end

