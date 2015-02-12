### All code in this file is provided under the LGPL license. Please read the file COPYING.
class Array
  def has_subset?(other_array)
    other_array.is_subset?(self)
  end
  def is_subset?(other_array)
    self.all? { |e| other_array.include?(e) }
  end
end
