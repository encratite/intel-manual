require 'nil/xml'

require_relative 'OpcodeTable'

class Instruction < Nil::XMLObject
  def initialize(name, opcodeTable, encodingTable, description, operation, flagsAffected, fpuFlagsAffected, exceptions)
    super()
    @name = name
    add(OpcodeTable.new(opcodeTable, encodingTable))
    add(Description.new(description))
    add(Operation.new(operation))
    add(FlagsAffected.new(flagsAffected)) if flagsAffected != nil
    add(FPUFlagsAffected.new(fpuFlagsAffected)) if fpuFlagsAffected != nil
    add(InstructionExceptionContainer.new(exceptions)) if exceptions != []
  end
end

class Description < Nil::XMLObject
  def initialize(description)
    super()
    setContent(description)
    setName('Description')
  end
end

class Operation < Nil::XMLObject
end

class FlagsAffected < Nil::XMLObject
end

class FPUFlagsAffected < Nil::XMLObject
end

class InstructionExceptionEntry < Nil::XMLObject
  def initialize(exception, description)
    super()
    setName('Exception')
    if exception != nil
      @name = exception
    end
    @description = description
  end
end

class InstructionExceptionCategory < Nil::XMLObject
  def initialize(category, exceptionData)
    super()
    setName('Category')
    @category = category
    if exceptionData.class == String
      setContent(exceptionData)
    else
      exceptionData.each do |exception, description|
        if description.class != String
          raise "Invalid description: #{description.inspect}\nIn: #{exceptionData.inspect}"
        end
        add(InstructionExceptionEntry.new(exception, description))
      end
    end
  end
end

class InstructionExceptionContainer < Nil::XMLObject
  def initialize(exceptionMap)
    super()
    setName('Exceptions')
    #puts exceptionMap
    exceptionMap.each do |mode, exceptions|
      if exceptions != nil
        add(InstructionExceptionCategory.new(mode, exceptions))
      end
    end
  end
end
