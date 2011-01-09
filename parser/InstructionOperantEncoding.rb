require 'nil/xml'

class InstructionOperandEncodingEntry < Nil::XMLObject
end

class InstructionOperandEncoding < Nil::XMLObject
  attr_reader :identifier, :operands

  def initialize(identifier, operands)
    super()
    @identifier = identifier
    operands.each do |operand|
      add(InstructionOperandEncodingEntry.new(operand))
    end
  end
end
