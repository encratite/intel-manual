require_relative 'OpcodeTable'
require_relative 'InstructionOperantEncoding'

class Instruction
  def initialize(opcodeTableRows, encodingTable, operation, flagsAffected, fpuFlagsAffected)
    @opcodeTable = OpcodeTable.new(opcodeTableRows)
    @encodingTable = encodingTable
    @operation = operation
    @flagsAffected = flagsAffected
    @fpuFlagsAffected = fpuFlagsAffected
  end
end
