### All code in this file is provided under the LGPL license. Please read the file COPYING.
require File.expand_path(File.dirname(__FILE__) + '/relation')

class Subject
  attr_reader :id, :relations, :shortid
  @@counter = 0

  def initialize(shortid)
    @shortid = shortid
    @id = "s#{@@counter += 1}"
    @relations = []
  end

  def to_s
    "<Subject:#{self.__id__} #{@id} #{@relations.inspect}>"
  end
  def inspect
    self.to_s
  end
end
