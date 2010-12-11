class XMLNode
	attr_reader :tag
	attr_accessor :content

	def initialize(tag, content)
		@tag = tag
		@content = content
	end

	def visualiseContent
		output = ''
		content.each do |i|
			if i.class == XMLNode
				output += i.visualise
			else
				output += i
			end
		end
		return output
	end

	def visualise
		if @tag == nil
			output = visualiseContent
		else
			if @content == nil
				output = "<#{@tag} />"
			else
				output = "<#{@tag}>#{visualiseContent}</#{@tag}>"
			end
		end
		return output
	end
end
