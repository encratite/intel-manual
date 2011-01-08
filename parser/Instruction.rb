require_relative 'OpcodeTable'
require_relative 'InstructionOperantEncoding'

class Instruction
  def initialize(name, opcodeTableRows, encodingTable, operation, flagsAffected, fpuFlagsAffected)
    @name = name
    @opcodeTable = OpcodeTable.new(opcodeTableRows)
    @encodingTable = encodingTable
    @operation = operation
    @flagsAffected = flagsAffected
    @fpuFlagsAffected = fpuFlagsAffected
  end
end
