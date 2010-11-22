require_relative 'OpcodeTable'

class Instruction
	def initialize(opcodeTableRows)
		@table = OpcodeTable.new(opcodeTableRows)
	end
end
