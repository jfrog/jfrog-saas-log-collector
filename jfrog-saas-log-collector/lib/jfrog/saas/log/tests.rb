
class Clas

  @class_ins_var = "class instance variable value"  #class instance variable
  @@class_var = "class variable value" #class  variable
  
  attr_accessor :class_ins_var, :class_var

  def self.class_ins_var
    @class_ins_var
  end

  def self.class_var
    @@class_var
  end

  def self.class_method
    puts "\nClass Method for Instance Var: #{@class_ins_var}"
    puts "Class Method for Class Var: #{@@class_var}"
  end

  def instance_method
    puts "\nInstance Method for Instance Var: #{@class_ins_var}"
    puts "Instance Method for Class Var: #{@@class_var}"
  end
end


puts "\nCalling Clas.class_method:"
Clas.class_method

puts "\nsee the difference"

instance = Clas.new

puts "\nCalling instance.instance_method:"
instance.instance_method
instance.class_ins_var = "class_inst_var modified on instance/object"
instance.class_var = "class_var modified on instance/object"
instance.instance_method


class ClasChild < Clas


end

puts "\nCalling ClasChild.class_method:"
ClasChild.class_method