require 'nil/file'

class ManualData
	def processPath(path)
		data = Nil.readFile(path)
		raise "Unable to read manual file \"#{path}\"" if data == nil
		instructionPattern = /<Sect>.*?<H4 id="LinkTarget_\d+">(.+?) <\/H4>(.*?)<\/Sect>/m
		data.scan(instructionPattern) do |match|
			title, content = match
			parseInstruction(title, content)
		end
	end
	
	def parseInstruction(title, content)
		puts title
		
		instructionPattern = /<Table>(.*?<T[HD]>Instruction.?<\/T[HD]>.*?)<\/Table>/m
		rowPattern = /<TR>(.*?)<\/TR>/m
		columnPattern = /<T[HD]>(.*?)<\/T[HD]>|(<)\/T[HD]>/
		
		match = instructionPattern.match(content)
		if match == nil
			puts "This is not an instruction section"
			return
		end 
		
		rows = []
		rowsData = match[1]
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
		puts rows.first.inspect
	end
end
