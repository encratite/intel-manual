require 'nil/file'
require_relative 'Instruction'

class ManualData
	def initialize
		@instructions = []
	end

	def processPath(path)
		data = Nil.readFile(path)
		raise "Unable to read manual file \"#{path}\"" if data == nil
		instructionPattern = /<Sect>.*?<H4 id="LinkTarget_\d+">(.+?) <\/H4>(.*?)<\/Sect>/m
		data = data.gsub("\r", '')
		data.scan(instructionPattern) do |match|
			title, content = match
			parseInstruction(title, content)
		end
	end

	def postProcessRows(rows)
		return if rows.empty?
		headerColumns = rows.first.size
		rows[1..-1].each do |row|
			difference = headerColumns - row.size
			case difference
			when 1
				#we have discovered a case of column merges in the XML output
				mergeOffset = 1
				mergedColumn = row[mergeOffset]
				case mergedColumn
				when nil
					#the merged column is part of a split row - just replicate the nil
					row.insert(mergeOffset, nil)
					next					
				end
				targets = ['A', 'B', 'Valid']
				hit = false
				targets.each do |target|
					string = target + ' '
					lastOffset = mergedColumn.size - string.size
					if mergedColumn[lastOffset..-1] == string
						mergedColumn.replace(mergedColumn[0..lastOffset])
						row.insert(mergeOffset + 1, target)
						hit = true
					end
				end
				if hit == false
					raise "Unable to split up erroneously merged columns: #{row.inspect}"
				end
			when 0
				#everything is in order				
			else
				raise "Invalid row length discrepancy of #{difference}: #{rows.inspect}"
			end
		end
	end

	def parseTable(input)	
		rowPattern = /<TR>(.*?)<\/TR>/m
		columnPattern = /<T[HD]>(.*?)<\/T[HD]>|(<)T[HD]\/>/
		rows = []
		input.scan(rowPattern) do |match|
			columns = []
			match.first.scan(columnPattern) do |match|
				columns << match.first
			end
			rows << columns
		end
		return rows
	end

	def extractRows(tableContent)
		rows = parseTable(tableContent)
		lastCompleteRow = nil
		output = []
		rows.each do |row|
			append = false
			row.each do |column|
				if column == nil
					append = true
				end
			end
			if append
				if output.empty?
					raise 'Encountered an empty column in the first row'
				end
				lastRow = output[-1]
				row.size.times do |i|
					toAppend = row[i]
					next if toAppend == nil
					lastRow[i] += toAppend
				end
			else
				output << row
			end
		end

		begin
			postProcessRows(output)
		rescue => exception
			raise exception
		end

		return output
	end

	def extractEncodingParagraph(input)
		encodingParagraphPattern = /<P>Op\/En Operand 1 Operand 2 Operand 3 Operand 4.*\n(.+?)\n<\/P>/
		match = encodingParagraphPattern.match(input)
		return nil if match == nil
		content = match[1]

		targets =
		[
			'imm8/16/32/64',
			'Displacement',
			'AL/AX/EAX/RAX',
			'implicit XMM0',
			'reg (r)',
			'reg (w)',
			'reg (r, w)',
			'Offset',
			'ModRM:reg (r)',
			'ModRM:reg (w)',
			'ModRM:reg (r, w)',
			'ModRM:r/m (r)',
			'ModRM:r/m (w)',
			'ModRM:r/m (r, w)',
			'imm8',
			'iw',
			'NA',
			'A',
			'B',
			'C',
		]
		i = 0
		output = []
		while i < content.size
			if content[i] == ' '
				i += 1
				next
			end
			foundTarget = false
			targets.each do |target|
				remaining = content.size - i
				if target.size > remaining
					next
				end
				substring = content[i..i + target.size - 1]
				if substring == target
					foundTarget = true
					output << target
					i += target.size
					break
				end
			end
			if !foundTarget
				raise "Unable to process encoding string #{content.inspect}, previous matches were #{output.inspect}"
			end
		end
		return [output]
	end

	def extractEncodingTable(content)
		tablePattern = /<Table>(.*<TR>.*<TD>Operand 1 <\/TD>.+?)<\/Table>/
		match = tablePattern.match(content)
		return nil if match == nil

		rows = parseTable(match[1])
		if rows.size < 2
			raise "Invalid instruction encoding table: #{rows.inspect}"
		end

		#Ignore the header
		return rows[1..-1]
	end
	
	def parseInstruction(title, content)
		puts title
		
		tablePattern = /<Table>(.*?)<\/Table>/m
		instructionPattern = /<T[HD]>Instruction.?<\/T[HD]>/
		descriptionPattern = /<P>Description <\/P>/
		jumpString = 'Transfers program control'
		
		error = proc do |reason|
			puts "This is not an instruction section (#{reason} match failed)"
			return
		end
		
		tableMatch = tablePattern.match(content)
		descriptionMatch = descriptionPattern.match(content)
		if tableMatch == nil
			error.call('table')
		end
		
		#the JMP instruction has an irregular description tag within a table
		if descriptionMatch == nil && content.index(jumpString) == nil
			error.call('description')
		end

		tableContent = tableMatch[1]
		instructionMatch = instructionPattern.match(tableContent)
		if instructionMatch == nil
			error.call('instruction')
		end
	
		rows = extractRows(tableContent)

		encodingParagraph = extractEncodingParagraph(content)
		if encodingParagraph == nil
			encodingTable = extractEncodingTable(content)
		end
		
		instruction = Instruction.new(rows, encodingTable)
		
		@instructions << instruction
	end
end
