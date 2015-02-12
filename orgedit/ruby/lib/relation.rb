### All code in this file is provided under the LGPL license. Please read the file COPYING.
class Relation
  attr_reader :unit, :role

  def initialize(unit,role)
    @unit = unit
    @role = role
  end

  def to_s
    "<Relation:#{self.__id__} #{@unit} #{@role}>"
  end
  def inspect
    self.to_s
  end
end
