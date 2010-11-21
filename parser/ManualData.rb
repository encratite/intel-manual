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
				if mergedColumn == nil
					#the merged column is part of a split row - just replicate the nil
					row.insert(mergeOffset, nil)
					next					
				end
				targets = ['A', 'B']
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
		
		instructionPattern = /<Table>(.*?<T[HD]>Instruction.?<\/T[HD]>.*?)<\/Table>/m
		descriptionPattern = /<P>Description <\/P>/
		rowPattern = /<TR>(.*?)<\/TR>/m
		columnPattern = /<T[HD]>(.*?)<\/T[HD]>|(<)T[HD]\/>/
		
		match1 = instructionPattern.match(content)
		match2 = descriptionPattern.match(content)
		if match1 == nil || match2 == nil
			puts "This is not an instruction section"
			return
		end 
		
		rows = []
		rowsData = match1[1]
		rowsData.scan(rowPattern) do |match|
			columns = []
			columnData = match.first
			append = false
			columnData.scan(columnPattern) do |match|
				column = match.first
				if column == '<'
					column = nil
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

		postProcessRows(rows)

		instruction = Instruction.new(rows)
		
		@instructions << instruction
	end
end
