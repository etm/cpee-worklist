### All code in this file is provided under the LGPL license. Please read the file COPYING.
class Node
  attr_reader :rank, :id, :type, :twidth, :theight, :subjects
  attr_accessor :parents, :rank, :order, :group, :numsubjects

  def initialize(id,type,opts)
    @type = type
    @id = id
    @rank = 0
    @parents = []
    @group = 0
    @numsubjects = 0
    @subjects = []
    @twidth = SVG::width_of(id)
    @theight = SVG::height_of(id)
    opts.each do |k,v|
      instance_variable_set(:"@#{k}",v)
      (class << self; self; end).class_eval do
        attr_accessor k.to_sym
      end
    end
  end

  def to_s
    "<Node:#{self.__id__} #{@id} #{type} #{@parents.inspect}>"
  end
  def inspect
    self.to_s
  end  
end
