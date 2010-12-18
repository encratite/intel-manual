class InstructionOperandEncoding
  attr_reader :identifier, :operands

  def initialize(identifier, operands)
    @identifier = identifier
    @operands = operands
  end
end
