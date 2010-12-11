class XMLNode
	#if it's the root node, then the tag is nil
	attr_reader :tag
	#if it's a <tag /> without any content, then this member will be nil
	attr_accessor :content

	def initialize(tag, content, attributes = {})
		tag = tag.downcase if tag != nil
		@tag = tag
		@content = content
		@attributes = attributes
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

	def mainString
		output = @tag
		@attributes.each do |key, value|
			output += " #{key}=\"#{value}\""
		end
	end

	def visualise
		if @tag == nil
			output = visualiseContent
		else
			if @content == nil
				output = "<#{mainString} />"
			else
				output = "<#{mainString}>#{visualiseContent}</#{@tag}>"
			end
		end
		return output
	end
end
