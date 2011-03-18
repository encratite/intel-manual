require 'nil/xml'

class InstructionOperandEncodingEntry < Nil::XMLObject
  attr_reader :description

  def initialize(description)
    super()
    setName('Operand')
    @description = description
  end
end

class InstructionOperandEncoding < Nil::XMLObject
  attr_reader :identifier

  def initialize(identifier, operands)
    super()
    setName('OperandEncoding')
    @identifier = identifier
    operands.each do |operand|
      add(InstructionOperandEncodingEntry.new(operand))
    end
  end
end
