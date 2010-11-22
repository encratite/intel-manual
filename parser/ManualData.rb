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
	
	def parseInstruction(title, content)
		puts title
		
		tablePattern = /<Table>(.*?)<\/Table>/m
		instructionPattern = /<T[HD]>Instruction.?<\/T[HD]>/
		descriptionPattern = /<P>Description <\/P>/
		jumpString = 'Transfers program control'
		rowPattern = /<TR>(.*?)<\/TR>/m
		columnPattern = /<T[HD]>(.*?)<\/T[HD]>|(<)T[HD]\/>/

		error = proc do |reason|
			puts "This is not an instruction section (#{reason})"
			return
		end
		
		tableMatch = tablePattern.match(content)
		descriptionMatch = descriptionPattern.match(content)
		if tableMatch == nil
			error.call('table match failed')
		end
		
		#the JMP instruction has an irregular description tag within a table
		if descriptionMatch == nil && content.index(jumpString) == nil
			error.call('description match failed')
		end

		tableContent = tableMatch[1]
		instructionMatch = instructionPattern.match(tableContent)
		if instructionMatch == nil
			error.call('instruction match failed')
		end
		
		rows = []
		tableContent.scan(rowPattern) do |match|
			columns = []
			columnData = match.first
			append = false
			columnData.scan(columnPattern) do |match|
				column = match.first
				if column == nil
					append = true
				end
				columns << column
			end
			if append
				lastRow = rows[-1]
				columns.size.times do |i|
					toAppend = columns[i]
					next if toAppend == nil
					lastRow[i] += toAppend
				end
			else
				rows << columns
			end
		end

		begin
			postProcessRows(rows)
		rescue => exception
			#puts instructionMatch[1].inspect
			raise exception
		end

		instruction = Instruction.new(rows)
		
		@instructions << instruction
	end
end
