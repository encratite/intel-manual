require 'nil/xml'

require_relative 'InstructionExceptionCategory'

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
