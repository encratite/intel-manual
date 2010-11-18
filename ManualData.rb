require 'nil/file'

class ManualData
	def processPath(path)
		data = Nil.readFile(path)
		raise "Unable to read manual file \"#{path}\"" if data == nil
		instructionPattern = /<Sect>.*?<H4 id="LinkTarget_\d+">(.+?) <\/H4>(.*?)<\/Sect>/m
		data.scan(instructionPattern) do |match|
			title, content = match
			puts title
		end
	end
end
