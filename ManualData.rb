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
		#pattern = /<Table>.*?<TR>.*?<T.>Opcode <\/T.>.*?<T.>Instruction <\/T.>.*?<T.>Op\/ <\/T.>.*?<T.>64-bit <\/T.>.*?<T.>Compat\/ <\/T.>.*?<T.>Description <\/T.><\/TR>(.*)<\/Table>/m
		pattern = /<Table>.*?<TR>.*?<T.>Opcode <\/T.>.*?<T.>Instruction <\/T.>.*?<T.>Op\/ <\/T.>/m
		match = pattern.match(content)
		if match == nil
			puts "This is not an instruction section"
			return
		end 
		rows = match[1]
		pattern = /<TR>.*?(<TD>(.*?)<\/TD>.*?|<TD\/>.*?)+<\/TR>/m
		match = pattern.match(rows)
		if match == nil
			puts "Unable to match rows"
			return
		end 
		puts match.inspect
	end
end
