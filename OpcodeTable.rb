require_relative 'OpcodeTableEntry'
require_relative 'InstructionOperantEncoding'

class OpcodeTable
	attr_reader :opcodes, :encoding
	
	def initialize(rows)
		@encoding = nil
		parseRows(rows)
	end
	
	def parseRows(rows)
		header = rows.first
		interpretation = [:opcode, :instruction]
		case header.size
		when 6
			interpretation << :
		end
		interpretation += [:longMode, :legacyMode, :description]
		rows.each do |columns|
	end
end
