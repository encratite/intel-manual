require_relative 'OpcodeTable'
require_relative 'InstructionOperantEncoding'

class Instruction
  def initialize(opcodeTableRows, encodingTable, operation, flagsAffected)
    @opcodeTable = OpcodeTable.new(opcodeTableRows)
    @encodingTable = encodingTable
    @operation = operation
    @flagsAffected = flagsAffected
  end
end
