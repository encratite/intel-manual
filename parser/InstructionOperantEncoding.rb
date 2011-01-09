require 'nil/xml'

class InstructionOperandEncodingEntry < Nil::XMLObject
  def initialize(description)
    super()
    setName('Operand')
    @description = description
  end
end

class InstructionOperandEncoding < Nil::XMLObject
  attr_reader :identifier, :operands

  def initialize(identifier, operands)
    super()
    setName('OperandEncoding')
    @identifier = identifier
    operands.each do |operand|
      add(InstructionOperandEncodingEntry.new(operand))
    end
  end
end
