require_relative 'OpcodeTable'
require_relative 'InstructionOperantEncoding'

class Instruction
  def initialize(opcodeTableRows, encodingTable, operation)
    @opcodeTable = OpcodeTable.new(opcodeTableRows)
    @encodingTable = encodingTable
    @operation = operation
  end
end
