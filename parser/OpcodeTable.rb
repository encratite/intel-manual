require_relative 'OpcodeTableEntry'
require_relative 'InstructionOperantEncoding'

class OpcodeTable
	attr_reader :opcodes, :encoding
	
	def initialize(rows)
		@encoding = nil
		@instructions = []
		parseRows(rows)
	end

	def interpretColumn(columns, symbol, interpretation)
		offset = interpretation.index(symbol)
		return nil if offset == nil
		if columns.size <= offset
			raise "Not enough columns for symbol #{symbol.inspect}: #{columns.inspect}"
		end
		return columns[offset]
	end
	
	def parseRows(rows)
		header = rows.first
		interpretation = [:opcode, :instruction]
		case header.size
		when 6
			interpretation << :encodingIdentifier
		when 5
			#this is used by the FPU instructions which have no encoding identifiers specified
		else
			raise "Invalid header size detected in a table: #{header.size} (#{header.inspect})"
		end
		interpretation += [:longMode, :legacyMode, :description]
		rows.each do |columns|
			entry = OpcodeTableEntry.new
			interpretation.each do |symbol|
				value = interpretColumn(columns, symbol, interpretation)
				entry.setMember(symbol, value)
			end
			@instructions << entry
		end
	end

	def setEncoding(encodingTable)
		if encodingTable != nil
			@encoding = encodingTable.map do |row|
				InstructionOperandEncoding.new(row[0], row[1..-1])
			end
		end
	end
end
