require_relative 'OpcodeTable'
require_relative 'InstructionOperantEncoding'

class Instruction
	def initialize(opcodeTableRows, encodingTable)
		@opcodeTable = OpcodeTable.new(opcodeTableRows)
	end
end
