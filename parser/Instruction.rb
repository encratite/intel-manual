require_relative 'OpcodeTable'
require_relative 'InstructionOperandEncoding'

class Instruction
	def initialize(opcodeTableRows, encodingTable)
		@opcodeTable = OpcodeTable.new(opcodeTableRows)
	end
end
